(in-package #:cl-webgpu/imgui)

;;;; ---------------------------------------------------------------------------
;;;; Dear ImGui -> wgpu rendering backend
;;;;
;;;; ImGui builds a retained ImDrawData tree each frame: one ImDrawList per
;;;; window/layer, each carrying its own vertex buffer, 16-bit index buffer and
;;;; a list of ImDrawCmd (a scissor rect + a texture + an index range). This
;;;; backend concatenates every list's vertices/indices into two growable GPU
;;;; buffers and issues one scissored draw-indexed call per command, switching
;;;; the group-1 bind group when the command's texture changes.
;;;;
;;;; It implements the 1.92 texture protocol
;;;; (ImGuiBackendFlags_RendererHasTextures): the font atlas and any
;;;; user-registered textures arrive through ImDrawData::Textures with a
;;;; per-frame create/update/destroy status that RENDER-IMGUI services before
;;;; drawing. There is no separate "bake the atlas" step.
;;;;
;;;; Mirrors the structure of cl-webgpu/nuklear's backend.lisp; the shader and
;;;; the premultiplied-alpha blend state are shared almost verbatim.
;;;; ---------------------------------------------------------------------------

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defconstant +vertex-stride+ 20
    "Bytes per ImDrawVert: float2 pos + float2 uv + u32 col (stock imconfig.h).")
  (defconstant +proj-buf-size+ 64
    "Projection matrix: mat4x4<f32> = 16 floats x 4 bytes.")
  (defconstant +initial-vtx-bytes+ (* 128 1024))
  (defconstant +initial-idx-bytes+ (*  64 1024)))

;;; WGSL: 2D textured + coloured quads with an ortho projection.
;;; group 0: binding 0 = projection uniform, binding 1 = sampler (built once).
;;; group 1: binding 0 = the draw command's texture (one bind group per texture).
(defparameter *imgui-wgsl*
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

@group(0) @binding(0) var<uniform> proj: mat4x4<f32>;
@group(0) @binding(1) var samp: sampler;
@group(1) @binding(0) var tex:  texture_2d<f32>;

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
    return textureSample(tex, samp, in.uv) * in.color;
}
")

;;; ---------------------------------------------------------------------------
;;; Renderer handle
;;; ---------------------------------------------------------------------------

(defstruct (imgui-renderer (:constructor %make-imgui-renderer))
  device
  pipeline
  proj-buffer
  sampler
  group0                 ; bind group: proj uniform + sampler
  group0-layout
  group1-layout          ; layout for the per-texture bind groups
  vertex-buffer          ; growable GPU vertex buffer
  vertex-capacity        ; bytes
  index-buffer           ; growable GPU index buffer (uint16)
  index-capacity         ; bytes
  vtx-staging            ; foreign CPU scratch, vertex-capacity bytes
  idx-staging            ; foreign CPU scratch, index-capacity bytes
  (textures (make-hash-table))  ; imgui tex-id (u64) -> texture-entry
  (next-tex-id 1))

(defstruct texture-entry
  texture      ; gpu-texture
  view         ; gpu-texture-view
  bind-group)  ; gpu-bind-group for group 1

;;; ---------------------------------------------------------------------------
;;; Ortho projection (column-major mat4x4<f32>), with a DisplayPos offset.
;;; Maps [L,R] x [T,B] (pixels, y-down) to NDC [-1,1] x [1,-1].
;;; ---------------------------------------------------------------------------

(defun %ortho (l r top b)
  (let ((m (make-array 16 :element-type 'single-float :initial-element 0.0)))
    (setf (aref m 0)  (/ 2.0 (- r l))
          (aref m 5)  (/ 2.0 (- top b))
          (aref m 10) 1.0
          (aref m 12) (/ (+ r l) (- l r))
          (aref m 13) (/ (+ top b) (- b top))
          (aref m 15) 1.0)
    m))

;;; ---------------------------------------------------------------------------
;;; make-imgui-renderer
;;; ---------------------------------------------------------------------------

(defun make-imgui-renderer (device queue surface-format &key (label "imgui"))
  "Create an ImGui renderer for a context that has already been created with
IG:CREATE-CONTEXT. Enables ImGuiBackendFlags_RendererHasTextures, so callers
MUST NOT also drive the legacy ImFontAtlas Build()/GetTexDataAsRGBA32() path --
the font atlas is uploaded lazily via RENDER-IMGUI's texture loop.

Call order: IG:CREATE-CONTEXT -> MAKE-IMGUI-RENDERER -> first IG:NEW-FRAME.
Returns an IMGUI-RENDERER; release it with FREE-IMGUI-RENDERER.

QUEUE is accepted for call-site symmetry with MAKE-NUKLEAR-RENDERER and for
forward compatibility; nothing is uploaded here (the font atlas is created
lazily by RENDER-IMGUI's texture loop, which takes its own QUEUE)."
  (declare (ignore queue))
  (let ((io (ig:get-io)))
    ;; OR the flags in -- the platform/input glue also writes this slot.
    (setf (cffi:foreign-slot-value io '(:struct ig:io) 'ig::backend-flags)
          (logior (cffi:foreign-slot-value io '(:struct ig:io) 'ig::backend-flags)
                  (cffi:foreign-enum-value 'ig:im-backend-flags :backend-flags-renderer-has-textures)
                  (cffi:foreign-enum-value 'ig:im-backend-flags :backend-flags-renderer-has-vtx-offset)))
    (setf (cffi:foreign-slot-value io '(:struct ig:io) 'ig::backend-renderer-name)
          "cl-webgpu/imgui"))
  (let* ((proj-buf (w:make-buffer device
                                  :size +proj-buf-size+
                                  :usage (logior cl-webgpu:+wgpu-buffer-usage-uniform+
                                                 cl-webgpu:+wgpu-buffer-usage-copy-dst+)
                                  :label "imgui-proj"))
         (sampler  (w:make-sampler device))
         (shader   (w:make-shader-module device *imgui-wgsl* :label "imgui-shader"))
         (pipeline (w:make-render-pipeline device
                    :vertex-module   shader
                    :fragment-module shader
                    :vertex-entry-point   "vs_main"
                    :fragment-entry-point "fs_main"
                    :surface-format  surface-format
                    ;; Standard premultiplied-alpha blend. Passing NIL/'() here
                    ;; would leave blending OFF (see cl-webgpu/nuklear), turning
                    ;; antialiased glyph coverage into solid blocks.
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
                    :label (format nil "~a-pipeline" label)))
         (g0-layout (w:get-pipeline-bind-group-layout pipeline 0))
         (g1-layout (w:get-pipeline-bind-group-layout pipeline 1))
         (g0 (w:make-bind-group device g0-layout
                                (list (list :binding 0 :buffer proj-buf :offset 0 :size +proj-buf-size+)
                                      (list :binding 1 :sampler sampler))))
         (vtx-buf (w:make-buffer device
                                 :size +initial-vtx-bytes+
                                 :usage (logior cl-webgpu:+wgpu-buffer-usage-vertex+
                                                cl-webgpu:+wgpu-buffer-usage-copy-dst+)
                                 :label "imgui-vertices"))
         (idx-buf (w:make-buffer device
                                 :size +initial-idx-bytes+
                                 :usage (logior cl-webgpu:+wgpu-buffer-usage-index+
                                                cl-webgpu:+wgpu-buffer-usage-copy-dst+)
                                 :label "imgui-indices")))
    (w:release shader)
    (%make-imgui-renderer
     :device device
     :pipeline pipeline
     :proj-buffer proj-buf
     :sampler sampler
     :group0 g0
     :group0-layout g0-layout
     :group1-layout g1-layout
     :vertex-buffer vtx-buf   :vertex-capacity +initial-vtx-bytes+
     :index-buffer  idx-buf   :index-capacity  +initial-idx-bytes+
     :vtx-staging (cffi:foreign-alloc :uint8 :count +initial-vtx-bytes+)
     :idx-staging (cffi:foreign-alloc :uint8 :count +initial-idx-bytes+))))

;;; ---------------------------------------------------------------------------
;;; Growable buffers
;;; ---------------------------------------------------------------------------

(defun %ensure-vertex-capacity (r need-bytes)
  (when (> need-bytes (imgui-renderer-vertex-capacity r))
    (let ((new (max need-bytes (ceiling (* 3 (imgui-renderer-vertex-capacity r)) 2))))
      (w:release (imgui-renderer-vertex-buffer r))
      (cffi:foreign-free (imgui-renderer-vtx-staging r))
      (setf (imgui-renderer-vertex-buffer r)
            (w:make-buffer (imgui-renderer-device r)
                           :size new
                           :usage (logior cl-webgpu:+wgpu-buffer-usage-vertex+
                                          cl-webgpu:+wgpu-buffer-usage-copy-dst+)
                           :label "imgui-vertices")
            (imgui-renderer-vertex-capacity r) new
            (imgui-renderer-vtx-staging r) (cffi:foreign-alloc :uint8 :count new)))))

(defun %ensure-index-capacity (r need-bytes)
  (when (> need-bytes (imgui-renderer-index-capacity r))
    (let ((new (max need-bytes (ceiling (* 3 (imgui-renderer-index-capacity r)) 2))))
      (w:release (imgui-renderer-index-buffer r))
      (cffi:foreign-free (imgui-renderer-idx-staging r))
      (setf (imgui-renderer-index-buffer r)
            (w:make-buffer (imgui-renderer-device r)
                           :size new
                           :usage (logior cl-webgpu:+wgpu-buffer-usage-index+
                                          cl-webgpu:+wgpu-buffer-usage-copy-dst+)
                           :label "imgui-indices")
            (imgui-renderer-index-capacity r) new
            (imgui-renderer-idx-staging r) (cffi:foreign-alloc :uint8 :count new)))))

;;; ---------------------------------------------------------------------------
;;; Texture lifecycle (ImGuiBackendFlags_RendererHasTextures)
;;; ---------------------------------------------------------------------------

(defun %vec-size (ptr struct)
  (cffi:foreign-slot-value ptr (list :struct struct) 'ig::size))
(defun %vec-data (ptr struct)
  (cffi:foreign-slot-value ptr (list :struct struct) 'ig::data))

(defun %tex-slot (td slot)
  (cffi:foreign-slot-value td '(:struct ig:texture-data) slot))

(defun %service-textures (r draw-data queue)
  "Walk ImDrawData::Textures (a POINTER to ImVector<ImTextureData*>) and honour
each entry's create/update/destroy request."
  (let ((vec (cffi:foreign-slot-value draw-data '(:struct ig:draw-data) 'ig::textures)))
    (when (or (null vec) (cffi:null-pointer-p vec))
      (return-from %service-textures))
    (let ((n   (%vec-size vec 'ig::vector-im-texture-data-ptr))
          (arr (%vec-data vec 'ig::vector-im-texture-data-ptr)))
      (dotimes (i n)
        (let* ((td     (cffi:mem-aref arr :pointer i))
               (status (%tex-slot td 'ig::status)))
          (case status
            (:texture-status-want-create (%texture-create  r td queue))
            (:texture-status-want-updates (%texture-update  r td queue))
            (:texture-status-want-destroy (%texture-destroy r td))))))))

(defun %texture-create (r td queue)
  (let* ((w  (%tex-slot td 'ig::width))
         (h  (%tex-slot td 'ig::height))
         (px (ig:texture-data-get-pixels td))
         (id (imgui-renderer-next-tex-id r)))
    (multiple-value-bind (tex view)
        (w:make-texture-2d (imgui-renderer-device r) w h
                           :format :rgba8-unorm :label "imgui-texture")
      (w:write-texture queue tex px (* w h 4)
                       :width w :height h :bytes-per-row (* w 4))
      (let ((bg (w:make-bind-group (imgui-renderer-device r)
                                   (imgui-renderer-group1-layout r)
                                   (list (list :binding 0 :texture-view view)))))
        (setf (gethash id (imgui-renderer-textures r))
              (make-texture-entry :texture tex :view view :bind-group bg))
        (incf (imgui-renderer-next-tex-id r))
        (ig:texture-data-set-tex-id td id)
        (ig:texture-data-set-status td :texture-status-ok)))))

(defun %texture-update (r td queue)
  (let* ((id (ig:texture-data-get-tex-id td))
         (entry (gethash id (imgui-renderer-textures r))))
    (when entry
      (let* ((ur (cffi:foreign-slot-pointer td '(:struct ig:texture-data) 'ig::update-rect))
             (ux (cffi:foreign-slot-value ur '(:struct ig:texture-rect) 'ig::x))
             (uy (cffi:foreign-slot-value ur '(:struct ig:texture-rect) 'ig::y))
             (uw (cffi:foreign-slot-value ur '(:struct ig:texture-rect) 'ig::w))
             (uh (cffi:foreign-slot-value ur '(:struct ig:texture-rect) 'ig::h))
             (pitch (ig:texture-data-get-pitch td))
             (src   (ig:texture-data-get-pixels-at td ux uy)))
        ;; DATA-SIZE for a strided sub-rect: pitch*(h-1) + w*bytesPerPixel.
        (w:write-texture queue (texture-entry-texture entry) src
                         (+ (* pitch (1- uh)) (* uw 4))
                         :width uw :height uh :bytes-per-row pitch
                         :x ux :y uy)))
    (ig:texture-data-set-status td :texture-status-ok)))

(defun %texture-destroy (r td)
  ;; ImGui keeps a texture flagged WantDestroy for a few frames (UnusedFrames);
  ;; only actually free it once that grace period has elapsed.
  (when (plusp (%tex-slot td 'ig::unused-frames))
    (let* ((id (ig:texture-data-get-tex-id td))
           (entry (gethash id (imgui-renderer-textures r))))
      (when entry
        (w:release (texture-entry-bind-group entry))
        (w:release (texture-entry-view entry))
        (w:release (texture-entry-texture entry))
        (remhash id (imgui-renderer-textures r)))
      (ig:texture-data-set-tex-id td 0) ; ImTextureID_Invalid
      (ig:texture-data-set-status td :texture-status-destroyed))))

;;; ---------------------------------------------------------------------------
;;; render-imgui
;;; ---------------------------------------------------------------------------

(defun render-imgui (renderer draw-data pass queue)
  "Upload DRAW-DATA (from IG:GET-DRAW-DATA, after IG:RENDER) and issue draw
calls on PASS. Call once per frame, inside the render pass, before
END-AND-SUBMIT. QUEUE is a GPU-QUEUE."
  (when (or (cffi:null-pointer-p draw-data)
            (not (cffi:foreign-slot-value draw-data '(:struct ig:draw-data) 'ig::valid)))
    (return-from render-imgui))
  ;; 1. Textures first -- always, even when there is nothing to draw, or a
  ;;    pending WantCreate would be stranded and trip an assert next frame.
  (%service-textures renderer draw-data queue)
  (let* ((dpos  (cffi:foreign-slot-pointer draw-data '(:struct ig:draw-data) 'ig::display-pos))
         (dsize (cffi:foreign-slot-pointer draw-data '(:struct ig:draw-data) 'ig::display-size))
         (fbs   (cffi:foreign-slot-pointer draw-data '(:struct ig:draw-data) 'ig::framebuffer-scale))
         (px (cffi:foreign-slot-value dpos  '(:struct ig:vec2) 'ig::x))
         (py (cffi:foreign-slot-value dpos  '(:struct ig:vec2) 'ig::y))
         (dw (cffi:foreign-slot-value dsize '(:struct ig:vec2) 'ig::x))
         (dh (cffi:foreign-slot-value dsize '(:struct ig:vec2) 'ig::y))
         (sx (cffi:foreign-slot-value fbs   '(:struct ig:vec2) 'ig::x))
         (sy (cffi:foreign-slot-value fbs   '(:struct ig:vec2) 'ig::y))
         (fb-w (round (* dw sx)))
         (fb-h (round (* dh sy)))
         (total-vtx (cffi:foreign-slot-value draw-data '(:struct ig:draw-data) 'ig::total-vtx-count))
         (total-idx (cffi:foreign-slot-value draw-data '(:struct ig:draw-data) 'ig::total-idx-count)))
    (when (or (<= fb-w 0) (<= fb-h 0) (zerop total-vtx) (zerop total-idx))
      (return-from render-imgui))
    ;; 2. Projection (logical display coords; scissor/viewport carry fb scale).
    (w:write-buffer queue (imgui-renderer-proj-buffer renderer) 0
                    (%ortho px (+ px dw) py (+ py dh)))
    ;; 3. Concatenate every cmd list's vertices/indices into the staging blocks.
    ;;    wgpuQueueWriteBuffer needs the byte count a multiple of 4; the vertex
    ;;    stride is 20 so that side is always aligned, but an odd total index
    ;;    count is not -- round its buffer up by one u16.
    (%ensure-vertex-capacity renderer (* total-vtx +vertex-stride+))
    (%ensure-index-capacity  renderer (* 4 (ceiling (* total-idx 2) 4)))
    (let* ((lists (cffi:foreign-slot-pointer draw-data '(:struct ig:draw-data) 'ig::cmd-lists))
           (n-lists (%vec-size lists 'ig::vector-im-draw-list-ptr))
           (list-arr (%vec-data lists 'ig::vector-im-draw-list-ptr))
           (vtx-stage (imgui-renderer-vtx-staging renderer))
           (idx-stage (imgui-renderer-idx-staging renderer))
           (vtx-bytes 0) (idx-bytes 0)
           ;; per-list running base counts, filled during the copy pass
           (bases (make-array n-lists)))
      (dotimes (li n-lists)
        (let* ((dl  (cffi:mem-aref list-arr :pointer li))
               (vb  (cffi:foreign-slot-pointer dl '(:struct ig:draw-list) 'ig::vtx-buffer))
               (ib  (cffi:foreign-slot-pointer dl '(:struct ig:draw-list) 'ig::idx-buffer))
               (vn  (%vec-size vb 'ig::vector-im-draw-vert))
               (in  (%vec-size ib 'ig::vector-im-draw-idx))
               (vsz (* vn +vertex-stride+))
               (isz (* in 2)))
          (setf (aref bases li) (cons (truncate vtx-bytes +vertex-stride+)
                                      (truncate idx-bytes 2)))
          (cffi:foreign-funcall "memcpy"
                                :pointer (cffi:inc-pointer vtx-stage vtx-bytes)
                                :pointer (%vec-data vb 'ig::vector-im-draw-vert)
                                :size vsz :void)
          (cffi:foreign-funcall "memcpy"
                                :pointer (cffi:inc-pointer idx-stage idx-bytes)
                                :pointer (%vec-data ib 'ig::vector-im-draw-idx)
                                :size isz :void)
          (incf vtx-bytes vsz)
          (incf idx-bytes isz)))
      (w:write-buffer queue (imgui-renderer-vertex-buffer renderer) 0 vtx-stage vtx-bytes)
      ;; pad the index upload to a 4-byte multiple (see step 3)
      (w:write-buffer queue (imgui-renderer-index-buffer  renderer) 0 idx-stage
                      (* 4 (ceiling idx-bytes 4)))
      ;; 4. Bind pipeline + shared state, then walk the commands.
      (w:set-pipeline pass (imgui-renderer-pipeline renderer))
      (w:set-vertex-buffer pass 0 (imgui-renderer-vertex-buffer renderer))
      (w:set-index-buffer  pass (imgui-renderer-index-buffer renderer) :format :uint16)
      (w:set-bind-group    pass 0 (imgui-renderer-group0 renderer))
      (dotimes (li n-lists)
        (let* ((dl   (cffi:mem-aref list-arr :pointer li))
               (cmds (cffi:foreign-slot-pointer dl '(:struct ig:draw-list) 'ig::cmd-buffer))
               (cn   (%vec-size cmds 'ig::vector-im-draw-cmd))
               (carr (%vec-data cmds 'ig::vector-im-draw-cmd))
               (vbase (car (aref bases li)))
               (ibase (cdr (aref bases li))))
          (dotimes (ci cn)
            (let* ((cmd (cffi:mem-aptr carr '(:struct ig:draw-cmd) ci))
                   (ucb (cffi:foreign-slot-value cmd '(:struct ig:draw-cmd) 'ig::user-callback)))
              (unless (and ucb (not (cffi:null-pointer-p ucb)))
                ;; PLACEHOLDER: user_callback draw commands (including the
                ;; ImDrawCallback_ResetRenderState sentinel) are skipped, not
                ;; run. A full backend would invoke the callback here and, for
                ;; the sentinel, re-bind pipeline/buffers/bind-groups after it.
                ;; Tracked on the sr.ht tracker.
                (let* ((elem (cffi:foreign-slot-value cmd '(:struct ig:draw-cmd) 'ig::elem-count))
                       (voff (cffi:foreign-slot-value cmd '(:struct ig:draw-cmd) 'ig::vtx-offset))
                       (ioff (cffi:foreign-slot-value cmd '(:struct ig:draw-cmd) 'ig::idx-offset))
                       (clip (cffi:foreign-slot-pointer cmd '(:struct ig:draw-cmd) 'ig::clip-rect))
                       (cx1 (cffi:foreign-slot-value clip '(:struct ig:vec4) 'ig::x))
                       (cy1 (cffi:foreign-slot-value clip '(:struct ig:vec4) 'ig::y))
                       (cx2 (cffi:foreign-slot-value clip '(:struct ig:vec4) 'ig::z))
                       (cy2 (cffi:foreign-slot-value clip '(:struct ig:vec4) 'ig::w))
                       ;; clip rect -> framebuffer space (DisplayPos-relative)
                       (sx1 (max 0 (round (* (- cx1 px) sx))))
                       (sy1 (max 0 (round (* (- cy1 py) sy))))
                       (sx2 (min fb-w (round (* (- cx2 px) sx))))
                       (sy2 (min fb-h (round (* (- cy2 py) sy)))))
                  (when (and (plusp elem) (> sx2 sx1) (> sy2 sy1))
                    (let* ((tid (ig:draw-cmd-get-tex-id cmd))
                           (entry (gethash tid (imgui-renderer-textures renderer))))
                      (when entry
                        (w:set-bind-group pass 1 (texture-entry-bind-group entry))
                        (w:set-scissor-rect pass sx1 sy1 (- sx2 sx1) (- sy2 sy1))
                        (w:draw-indexed pass elem
                                        :first-index (+ ibase ioff)
                                        :base-vertex (+ vbase voff))))))))))))))

;;; ---------------------------------------------------------------------------
;;; free-imgui-renderer
;;; ---------------------------------------------------------------------------

(defun free-imgui-renderer (renderer)
  "Release every GPU resource held by RENDERER, including all live ImGui
textures (walking ImGui::GetPlatformIO().Textures for any this backend still
owns)."
  (maphash (lambda (id entry)
             (declare (ignore id))
             (w:release (texture-entry-bind-group entry))
             (w:release (texture-entry-view entry))
             (w:release (texture-entry-texture entry)))
           (imgui-renderer-textures renderer))
  (clrhash (imgui-renderer-textures renderer))
  (w:release (imgui-renderer-group0 renderer))
  (w:release (imgui-renderer-group0-layout renderer))
  (w:release (imgui-renderer-group1-layout renderer))
  (w:release (imgui-renderer-sampler renderer))
  (w:release (imgui-renderer-proj-buffer renderer))
  (w:release (imgui-renderer-vertex-buffer renderer))
  (w:release (imgui-renderer-index-buffer renderer))
  (w:release (imgui-renderer-pipeline renderer))
  (cffi:foreign-free (imgui-renderer-vtx-staging renderer))
  (cffi:foreign-free (imgui-renderer-idx-staging renderer))
  (values))
