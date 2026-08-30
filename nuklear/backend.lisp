(in-package #:cl-webgpu/nuklear)

;;;; ---------------------------------------------------------------------------
;;;; Nuklear → wgpu rendering backend
;;;;
;;;; Nuklear acts as a retained-command layer: the user builds UI each frame, then
;;;; calls RENDER-NUKLEAR which calls nk_convert to produce a vertex buffer, index
;;;; buffer, and a list of draw commands.  This backend uploads those buffers and
;;;; issues one scissored draw-indexed call per command.
;;;;
;;;; NOTE: The vertex/index buffers are fixed-size (see +vtx-buf-size+/+idx-buf-size+).
;;;; A follow-up ticket should implement dynamic resizing when the buffer overflows.
;;;; ---------------------------------------------------------------------------

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defconstant +vtx-buf-size+  (* 512 1024) "Vertex buffer capacity in bytes.")
  (defconstant +idx-buf-size+  (* 128 1024) "Index buffer capacity in bytes (uint16).")
  (defconstant +cmd-buf-size+  (* 64  1024) "Nuklear command buffer capacity in bytes.")
  (defconstant +vertex-stride+ 20           "Bytes per vertex: float2 pos + float2 uv + uint8x4 color.")
  (defconstant +proj-buf-size+ 64           "Projection matrix: mat4x4<f32> = 16 floats × 4 bytes."))

;;; Nuklear vertex layout for nk_convert_config:
;;;   attribute 0 = NK_VERTEX_POSITION  format = NK_FORMAT_FLOAT   offset = 0
;;;   attribute 1 = NK_VERTEX_TEXCOORD  format = NK_FORMAT_FLOAT   offset = 8
;;;   attribute 2 = NK_VERTEX_COLOR     format = NK_FORMAT_R8G8B8A8 offset = 16
;;;   terminator  = NK_VERTEX_ATTRIBUTE_COUNT / NK_FORMAT_COUNT
(defun %make-vertex-layout ()
  (let* ((n    4)  ; 3 attributes + 1 terminator
         (ptr  (cffi:foreign-alloc '(:struct nuklear::nk-draw-vertex-layout-element) :count n)))
    (flet ((set-elem (i attr fmt off)
             (let ((e (cffi:mem-aptr ptr '(:struct nuklear::nk-draw-vertex-layout-element) i)))
               (setf (cffi:foreign-slot-value e '(:struct nuklear::nk-draw-vertex-layout-element) 'nuklear::attribute) attr
                     (cffi:foreign-slot-value e '(:struct nuklear::nk-draw-vertex-layout-element) 'nuklear::format)    fmt
                     (cffi:foreign-slot-value e '(:struct nuklear::nk-draw-vertex-layout-element) 'nuklear::offset)    off))))
      (set-elem 0 :nk-vertex-position :nk-format-float    0)
      (set-elem 1 :nk-vertex-texcoord :nk-format-float    8)
      (set-elem 2 :nk-vertex-color    :nk-format-r8g8b8a8 16)
      (set-elem 3 :nk-vertex-attribute-count :nk-format-count 0))
    ptr))

;;; WGSL shader: 2D textured + colored quads with an ortho projection.
;;; Group 0: binding 0 = projection uniform, binding 1 = atlas texture, binding 2 = atlas sampler.
(defparameter *nuklear-wgsl*
  "struct VertexInput {
    @location(0) pos:   vec2<f32>,
    @location(1) uv:    vec2<f32>,
    @location(2) color: vec4<f32>,
}

struct VertexOutput {
    @builtin(position) clip_position: vec4<f32>,
    @location(0) uv:    vec2<f32>,
    @location(1) color: vec4<f32>,
}

@group(0) @binding(0) var<uniform>  proj:          mat4x4<f32>;
@group(0) @binding(1) var           atlas_texture: texture_2d<f32>;
@group(0) @binding(2) var           atlas_sampler: sampler;

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;
    out.clip_position = proj * vec4<f32>(in.pos, 0.0, 1.0);
    out.uv    = in.uv;
    out.color = in.color;
    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    return textureSample(atlas_texture, atlas_sampler, in.uv) * in.color;
}
")

;;; ---------------------------------------------------------------------------
;;; Renderer struct (a simple plist-based handle)
;;; ---------------------------------------------------------------------------

;;; :CONSTRUCTOR is renamed to avoid colliding with the MAKE-NUKLEAR-RENDERER
;;; defun below (the public constructor, which builds the GPU resources and
;;; then calls %MAKE-NUKLEAR-RENDERER to assemble the struct). Without this,
;;; DEFSTRUCT's default MAKE-NUKLEAR-RENDERER constructor is clobbered by the
;;; later DEFUN of the same name, so the DEFUN's own call to
;;; "(make-nuklear-renderer :pipeline ...)" recurses into itself with keyword
;;; args instead of reaching the struct constructor.
(defstruct (nuklear-renderer (:constructor %make-nuklear-renderer))
  pipeline
  vertex-buffer
  index-buffer
  proj-buffer
  atlas-texture
  atlas-view
  sampler
  bind-group
  bind-group-layout
  vertex-layout       ; foreign nk-draw-vertex-layout-element array (caller frees)
  vtx-nk-buf          ; foreign nk-buffer for vertices
  idx-nk-buf          ; foreign nk-buffer for indices
  cmds-nk-buf         ; foreign nk-buffer for commands
  atlas-pixels        ; pointer to baked font atlas pixels (valid until atlas-end)
  atlas-width
  atlas-height
  atlas-null-tex)     ; foreign nk-draw-null-texture (populated by nk-font-atlas-end)

;;; ---------------------------------------------------------------------------
;;; Ortho projection matrix (column-major mat4x4<f32>)
;;; Maps pixel coords (0,0)→(W,H) to NDC (-1,1)→(1,-1).
;;; ---------------------------------------------------------------------------

(defun %ortho-matrix (width height)
  "Return a (simple-array single-float (16)) for a 2D ortho projection."
  (let ((m (make-array 16 :element-type 'single-float :initial-element 0.0))
        (l 0.0) (r (float width 1.0))
        (b (float height 1.0)) (top 0.0))
    ;; Column 0
    (setf (aref m 0) (/ 2.0 (- r l)))
    ;; Column 1
    (setf (aref m 5) (/ 2.0 (- top b)))
    ;; Column 2
    (setf (aref m 10) 1.0)
    ;; Column 3
    (setf (aref m 12) (- (/ (+ r l) (- r l)))
          (aref m 13) (- (/ (+ top b) (- top b)))
          (aref m 14) 0.0
          (aref m 15) 1.0)
    m))

(defun %upload-proj (queue proj-buffer width height)
  (cl-webgpu/wrapper:write-buffer queue proj-buffer 0 (%ortho-matrix width height)))

;;; ---------------------------------------------------------------------------
;;; make-nuklear-renderer
;;; ---------------------------------------------------------------------------

(defun make-nuklear-renderer (device queue width height surface-format
                              atlas atlas-pixels atlas-w atlas-h)
  "Create a nuklear renderer.  Returns a NUKLEAR-RENDERER.

ATLAS         — foreign nk_font_atlas pointer (from nk-font-atlas-init-default).
ATLAS-PIXELS  — foreign pixel data pointer returned by nk-font-atlas-bake.
ATLAS-W/H     — dimensions of the baked atlas.
SURFACE-FORMAT — the WGPUTextureFormat of the target surface (e.g. :bgra8-unorm).

Call FREE-NUKLEAR-RENDERER when done."
  ;; 1. GPU buffers
  (let* ((vtx-buf  (cl-webgpu/wrapper:make-buffer device
                    :size +vtx-buf-size+
                    :usage (logior cl-webgpu:+wgpu-buffer-usage-vertex+
                                   cl-webgpu:+wgpu-buffer-usage-copy-dst+)
                    :label "nk-vertices"))
         (idx-buf  (cl-webgpu/wrapper:make-buffer device
                    :size +idx-buf-size+
                    :usage (logior cl-webgpu:+wgpu-buffer-usage-index+
                                   cl-webgpu:+wgpu-buffer-usage-copy-dst+)
                    :label "nk-indices"))
         (proj-buf (cl-webgpu/wrapper:make-buffer device
                    :size +proj-buf-size+
                    :usage (logior cl-webgpu:+wgpu-buffer-usage-uniform+
                                   cl-webgpu:+wgpu-buffer-usage-copy-dst+)
                    :label "nk-proj")))
    ;; 2. Font atlas texture + upload
    (multiple-value-bind (atlas-tex atlas-view)
        (cl-webgpu/wrapper:make-texture-2d device atlas-w atlas-h
                                           :format :rgba8-unorm
                                           :label "nk-atlas")
      (cl-webgpu/wrapper:write-texture queue atlas-tex atlas-pixels
                                       (* atlas-w atlas-h 4)
                                       :width atlas-w :height atlas-h
                                       :bytes-per-row (* atlas-w 4))
      ;; 3. Inform nuklear of the atlas texture handle and get the null-texture
      (let* ((null-tex  (cffi:foreign-alloc '(:struct nuklear::nk-draw-null-texture)))
             (tex-handle (cffi:foreign-alloc '(:union nuklear::nk-handle))))
        ;; Store atlas-view pointer as the nuklear texture handle (nk-handle is a union)
        (setf (cffi:foreign-slot-value tex-handle '(:union nuklear::nk-handle) 'nuklear::ptr)
              (cl-webgpu/wrapper:handle atlas-view))
        (nuklear::nk-font-atlas-end atlas tex-handle null-tex)
        (cffi:foreign-free tex-handle)
        ;; 4. Sampler
        (let ((smp (cl-webgpu/wrapper:make-sampler device)))
          ;; 5. Pipeline (shader + vertex layout + blend)
          (let* ((shader   (cl-webgpu/wrapper:make-shader-module device *nuklear-wgsl*
                                                                 :label "nk-shader"))
                 (pipeline (cl-webgpu/wrapper:make-render-pipeline device
                            :vertex-module   shader
                            :fragment-module shader
                            :vertex-entry-point   "vs_main"
                            :fragment-entry-point "fs_main"
                            :surface-format  surface-format
                            ;; NOTE: :blend '() reads as NIL, and MAKE-RENDER-PIPELINE
                            ;; branches on (if blend ...), so it leaves blending OFF
                            ;; (weasel #84) -- pass the standard premultiplied-alpha
                            ;; defaults explicitly instead. Without this, every
                            ;; partially-transparent glyph/coverage pixel renders fully
                            ;; opaque, turning antialiased text into solid blobs.
                            :blend (list :color-src-factor :src-alpha
                                         :color-dst-factor :one-minus-src-alpha
                                         :color-operation :add
                                         :alpha-src-factor :one
                                         :alpha-dst-factor :one-minus-src-alpha
                                         :alpha-operation :add)
                            :vertex-buffer-layouts
                            (list (list :array-stride +vertex-stride+
                                        :step-mode :vertex
                                        :attributes
                                        (list (list :format :float32x2 :offset 0  :shader-location 0)
                                              (list :format :float32x2 :offset 8  :shader-location 1)
                                              (list :format :unorm8x4  :offset 16 :shader-location 2))))
                            :label "nk-pipeline")))
            ;; 6. Bind group (group 0: proj uniform, atlas texture, atlas sampler)
            (let* ((bg-layout (cl-webgpu/wrapper:get-pipeline-bind-group-layout pipeline 0))
                   (bg        (cl-webgpu/wrapper:make-bind-group
                               device bg-layout
                               (list (list :binding 0 :buffer proj-buf :offset 0 :size +proj-buf-size+)
                                     (list :binding 1 :texture-view atlas-view)
                                     (list :binding 2 :sampler smp))))
                   (layout    (%make-vertex-layout))
                   (vtx-nk    (cffi:foreign-alloc '(:struct nuklear::nk-buffer)))
                   (idx-nk    (cffi:foreign-alloc '(:struct nuklear::nk-buffer)))
                   (cmds-nk   (cffi:foreign-alloc '(:struct nuklear::nk-buffer))))
              (nuklear::nk-buffer-init-default vtx-nk)
              (nuklear::nk-buffer-init-default idx-nk)
              (nuklear::nk-buffer-init-default cmds-nk)
              ;; 7. Upload initial projection matrix
              (%upload-proj queue proj-buf width height)
              (cl-webgpu/wrapper:release shader)
              (%make-nuklear-renderer
               :pipeline        pipeline
               :vertex-buffer   vtx-buf
               :index-buffer    idx-buf
               :proj-buffer     proj-buf
               :atlas-texture   atlas-tex
               :atlas-view      atlas-view
               :sampler         smp
               :bind-group      bg
               :bind-group-layout bg-layout
               :vertex-layout   layout
               :vtx-nk-buf      vtx-nk
               :idx-nk-buf      idx-nk
               :cmds-nk-buf     cmds-nk
               :atlas-pixels    atlas-pixels
               :atlas-width     atlas-w
               :atlas-height    atlas-h
               :atlas-null-tex  null-tex))))))))

;;; ---------------------------------------------------------------------------
;;; render-nuklear
;;; ---------------------------------------------------------------------------

(defun render-nuklear (renderer ctx pass width height queue)
  "Convert the nuklear context CTX to GPU buffers and issue draw calls on PASS.

RENDERER — a NUKLEAR-RENDERER from MAKE-NUKLEAR-RENDERER.
CTX       — foreign nk_context pointer.
PASS      — a GPU-RENDER-PASS.
WIDTH/HEIGHT — framebuffer pixel dimensions (used for scissor clamping).
QUEUE     — a GPU-QUEUE (needed for write-buffer uploads)."
  ;; Re-upload the projection every frame from the caller's WIDTH/HEIGHT
  ;; (cheap: 64 bytes) instead of relying on the one-time upload in
  ;; MAKE-NUKLEAR-RENDERER, which goes stale as soon as the window resizes.
  (%upload-proj queue (nuklear-renderer-proj-buffer renderer) width height)
  (let* ((vtx-nk   (nuklear-renderer-vtx-nk-buf renderer))
         (idx-nk   (nuklear-renderer-idx-nk-buf renderer))
         (cmds-nk  (nuklear-renderer-cmds-nk-buf renderer))
         (layout   (nuklear-renderer-vertex-layout renderer))
         (null-tex (nuklear-renderer-atlas-null-tex renderer)))
    ;; Build nk_convert_config
    (cffi:with-foreign-object (cfg '(:struct nuklear::nk-convert-config))
      (cffi:foreign-funcall "memset" :pointer cfg :int 0
                            :size (cffi:foreign-type-size '(:struct nuklear::nk-convert-config)) :void)
      (setf (cffi:foreign-slot-value cfg '(:struct nuklear::nk-convert-config) 'nuklear::global-alpha) 1.0
            (cffi:foreign-slot-value cfg '(:struct nuklear::nk-convert-config) 'nuklear::line-AA)      :nk-anti-aliasing-on
            (cffi:foreign-slot-value cfg '(:struct nuklear::nk-convert-config) 'nuklear::shape-AA)     :nk-anti-aliasing-on
            (cffi:foreign-slot-value cfg '(:struct nuklear::nk-convert-config) 'nuklear::circle-segment-count) 22
            (cffi:foreign-slot-value cfg '(:struct nuklear::nk-convert-config) 'nuklear::arc-segment-count)    22
            (cffi:foreign-slot-value cfg '(:struct nuklear::nk-convert-config) 'nuklear::curve-segment-count)  22
            (cffi:foreign-slot-value cfg '(:struct nuklear::nk-convert-config) 'nuklear::vertex-layout)    layout
            (cffi:foreign-slot-value cfg '(:struct nuklear::nk-convert-config) 'nuklear::vertex-size)     +vertex-stride+
            (cffi:foreign-slot-value cfg '(:struct nuklear::nk-convert-config) 'nuklear::vertex-alignment) 1)
      ;; Copy null texture into config
      (let ((cfg-tex (cffi:foreign-slot-pointer cfg '(:struct nuklear::nk-convert-config) 'nuklear::tex-null)))
        (cffi:foreign-funcall "memcpy" :pointer cfg-tex :pointer null-tex
                              :size (cffi:foreign-type-size '(:struct nuklear::nk-draw-null-texture)) :void))
      ;; Clear nk buffers from last frame
      (nuklear::nk-buffer-clear vtx-nk)
      (nuklear::nk-buffer-clear idx-nk)
      (nuklear::nk-buffer-clear cmds-nk)
      ;; Convert
      (nuklear::nk-convert ctx cmds-nk vtx-nk idx-nk cfg)
      ;; Get vertex + index data pointers and sizes
      (let* ((vtx-mem  (cffi:foreign-slot-pointer vtx-nk '(:struct nuklear::nk-buffer) 'nuklear::memory))
             (idx-mem  (cffi:foreign-slot-pointer idx-nk '(:struct nuklear::nk-buffer) 'nuklear::memory))
             (vtx-ptr  (cffi:foreign-slot-value vtx-mem '(:struct nuklear::nk-memory) 'nuklear::ptr))
             (vtx-sz   (cffi:foreign-slot-value vtx-mem '(:struct nuklear::nk-memory) 'nuklear::size))
             (idx-ptr  (cffi:foreign-slot-value idx-mem '(:struct nuklear::nk-memory) 'nuklear::ptr))
             (idx-sz   (cffi:foreign-slot-value idx-mem '(:struct nuklear::nk-memory) 'nuklear::size))
             (vtx-buf  (nuklear-renderer-vertex-buffer renderer))
             (idx-buf  (nuklear-renderer-index-buffer renderer))
             (bg       (nuklear-renderer-bind-group renderer))
             (pipeline (nuklear-renderer-pipeline renderer)))
        (when (and (plusp vtx-sz) (plusp idx-sz))
          ;; Upload to GPU
          (cl-webgpu/wrapper:write-buffer queue vtx-buf 0 vtx-ptr vtx-sz)
          (cl-webgpu/wrapper:write-buffer queue idx-buf  0 idx-ptr  idx-sz)
          ;; Bind pipeline + buffers
          (cl-webgpu:wgpu-render-pass-encoder-set-pipeline
           (cl-webgpu/wrapper:handle pass)
           (cl-webgpu/wrapper:handle pipeline))
          (cl-webgpu/wrapper:set-vertex-buffer pass 0 vtx-buf)
          (cl-webgpu/wrapper:set-index-buffer  pass idx-buf :format :uint16)
          (cl-webgpu/wrapper:set-bind-group    pass 0 bg)
          ;; Iterate draw commands
          (let ((index-offset 0))
            (loop for cmd = (nuklear::nk--draw-begin ctx cmds-nk)
                           then (nuklear::nk--draw-next cmd cmds-nk ctx)
                  while (and cmd (not (cffi:null-pointer-p cmd)))
                  do (let ((elem-count (cffi:foreign-slot-value
                                        cmd '(:struct nuklear::nk-draw-command)
                                        'nuklear::elem-count)))
                       (when (plusp elem-count)
                         ;; Scissor rect — clamp to framebuffer bounds
                         (let* ((cr   (cffi:foreign-slot-pointer
                                       cmd '(:struct nuklear::nk-draw-command)
                                       'nuklear::clip-rect))
                                (cx   (min width  (max 0 (round (cffi:foreign-slot-value cr '(:struct nuklear::nk-rect) 'nuklear::x)))))
                                (cy   (min height (max 0 (round (cffi:foreign-slot-value cr '(:struct nuklear::nk-rect) 'nuklear::y)))))
                                (cw   (min (- width  cx) (round (cffi:foreign-slot-value cr '(:struct nuklear::nk-rect) 'nuklear::w))))
                                (ch   (min (- height cy) (round (cffi:foreign-slot-value cr '(:struct nuklear::nk-rect) 'nuklear::h)))))
                           (cl-webgpu/wrapper:set-scissor-rect pass cx cy (max 0 cw) (max 0 ch)))
                         (cl-webgpu/wrapper:draw-indexed pass elem-count :first-index index-offset)
                         (incf index-offset elem-count)))))))))
  ;; Clear nuklear state for next frame
  (nuklear::nk-clear ctx))

;;; ---------------------------------------------------------------------------
;;; free-nuklear-renderer
;;; ---------------------------------------------------------------------------

(defun free-nuklear-renderer (renderer)
  "Release all GPU resources held by RENDERER."
  (when (nuklear-renderer-bind-group   renderer) (cl-webgpu/wrapper:release           (nuklear-renderer-bind-group   renderer)))
  (when (nuklear-renderer-bind-group-layout renderer) (cl-webgpu/wrapper:release      (nuklear-renderer-bind-group-layout renderer)))
  (when (nuklear-renderer-sampler      renderer) (cl-webgpu/wrapper:release           (nuklear-renderer-sampler      renderer)))
  (when (nuklear-renderer-atlas-view   renderer) (cl-webgpu/wrapper:release           (nuklear-renderer-atlas-view   renderer)))
  (when (nuklear-renderer-atlas-texture renderer) (cl-webgpu/wrapper:release          (nuklear-renderer-atlas-texture renderer)))
  (when (nuklear-renderer-proj-buffer  renderer) (cl-webgpu/wrapper:release           (nuklear-renderer-proj-buffer  renderer)))
  (when (nuklear-renderer-index-buffer renderer) (cl-webgpu/wrapper:release           (nuklear-renderer-index-buffer renderer)))
  (when (nuklear-renderer-vertex-buffer renderer) (cl-webgpu/wrapper:release          (nuklear-renderer-vertex-buffer renderer)))
  (when (nuklear-renderer-pipeline     renderer) (cl-webgpu/wrapper:release           (nuklear-renderer-pipeline     renderer)))
  ;; Free nuklear-side buffers
  (when (nuklear-renderer-vtx-nk-buf  renderer)
    (nuklear::nk-buffer-free  (nuklear-renderer-vtx-nk-buf  renderer))
    (cffi:foreign-free        (nuklear-renderer-vtx-nk-buf  renderer)))
  (when (nuklear-renderer-idx-nk-buf  renderer)
    (nuklear::nk-buffer-free  (nuklear-renderer-idx-nk-buf  renderer))
    (cffi:foreign-free        (nuklear-renderer-idx-nk-buf  renderer)))
  (when (nuklear-renderer-cmds-nk-buf renderer)
    (nuklear::nk-buffer-free  (nuklear-renderer-cmds-nk-buf renderer))
    (cffi:foreign-free        (nuklear-renderer-cmds-nk-buf renderer)))
  (when (nuklear-renderer-vertex-layout renderer)
    (cffi:foreign-free (nuklear-renderer-vertex-layout renderer)))
  (when (nuklear-renderer-atlas-null-tex renderer)
    (cffi:foreign-free (nuklear-renderer-atlas-null-tex renderer))))
