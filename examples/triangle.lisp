;;;; examples/triangle.lisp
;;;; Minimal WebGPU triangle example using GLFW

;; Load the systems
(ql:quickload '(:cl-webgpu :cl-webgpu/glfw))

;; Run in the cl-webgpu package so struct slot symbols resolve correctly.
;; cl-glfw3 calls are qualified explicitly below.
(in-package #:cl-webgpu)

;; ============================================================================
;; Shader source
;; ============================================================================

(defparameter *vertex-shader-wgsl*
  "@vertex
fn main(@builtin(vertex_index) in_vertex_index: u32) -> @builtin(position) vec4<f32> {
    var pos = array<vec2<f32>, 3>(
        vec2<f32>( 0.0,  0.5),
        vec2<f32>(-0.5, -0.5),
        vec2<f32>( 0.5, -0.5)
    );
    return vec4<f32>(pos[in_vertex_index], 0.0, 1.0);
}")

(defparameter *fragment-shader-wgsl*
  "@fragment
fn main() -> @location(0) vec4<f32> {
    return vec4<f32>(1.0, 0.0, 0.0, 1.0);
}")

;; ============================================================================
;; Helpers
;; ============================================================================

(defun set-string-view (ptr string)
  "Set a WGPUStringView at PTR. Returns allocated foreign string data or nil."
  (if (and string (> (length string) 0))
      (let ((data (foreign-string-alloc string)))
        (setf (foreign-slot-value ptr '(:struct wgpu-string-view) 'data) data)
        (setf (foreign-slot-value ptr '(:struct wgpu-string-view) 'length) (length string))
        data)
      (progn
        (setf (foreign-slot-value ptr '(:struct wgpu-string-view) 'data) (null-pointer))
        (setf (foreign-slot-value ptr '(:struct wgpu-string-view) 'length) 0)
        nil)))

(defun create-shader-module (device source label)
  "Create a WGSL shader module from source string."
  (let ((shader-source (foreign-alloc '(:struct wgpu-shader-source-wgsl)))
        (descriptor (foreign-alloc '(:struct wgpu-shader-module-descriptor)))
        (code-data nil)
        (label-data nil))
    (unwind-protect
        (progn
          ;; Set up chained struct inside shader-source
          (let ((chain-ptr (foreign-slot-pointer shader-source '(:struct wgpu-shader-source-wgsl) 'chain)))
            (setf (foreign-slot-value chain-ptr '(:struct wgpu-chained-struct) 'next) (null-pointer))
            (setf (foreign-slot-value chain-ptr '(:struct wgpu-chained-struct) 's-type) 2)) ; WGPUSType_ShaderSourceWGSL

          ;; Set up code string view
          (setf code-data
                (set-string-view (foreign-slot-pointer shader-source '(:struct wgpu-shader-source-wgsl) 'code)
                                 source))

          ;; Set up descriptor
          (setf (foreign-slot-value descriptor '(:struct wgpu-shader-module-descriptor) 'next-in-chain)
                (foreign-slot-pointer shader-source '(:struct wgpu-shader-source-wgsl) 'chain))
          (setf label-data
                (set-string-view (foreign-slot-pointer descriptor '(:struct wgpu-shader-module-descriptor) 'label)
                                 label))

          (wgpu-device-create-shader-module device descriptor))
      (progn
        (when code-data (foreign-free code-data))
        (when label-data (foreign-free label-data))
        (foreign-free descriptor)
        (foreign-free shader-source)))))

;; ============================================================================
;; Main example
;; ============================================================================

(defun run-triangle-example ()
  "Run the WebGPU triangle example."

  ;; --- Load libraries ---
  (let* ((base-dir (asdf:system-source-directory :cl-webgpu))
         (shim-dir (namestring (merge-pathnames #P"shim/" base-dir)))
         (wgpu-dir (namestring (merge-pathnames #P"deps/wgpu-native/target/release/" base-dir))))
    (format t "Loading libraries from ~a and ~a~%" shim-dir wgpu-dir)
    (cl-webgpu:load-wgpu-libraries :wgpu-path wgpu-dir
                                   :shim-path shim-dir)
    (cl-webgpu/glfw:load-glfw-library :path shim-dir))

  ;; Disable SBCL floating-point traps (foreign libraries may trigger them)
  #+sbcl (sb-int:set-floating-point-modes :traps nil)

  ;; --- Initialize GLFW ---
  (cl-webgpu/glfw:initialize)

  ;; --- Create window (hints passed as keyword args) ---
  (let* (          (window (cl-webgpu/glfw:create-window :width 640 :height 480
                                         :title "WebGPU Triangle"
                                         :client-api :no-api
                                         :resizable nil))
         (instance nil)
         (adapter nil)
         (device nil)
         (surface nil)
         (pipeline nil)
         (width 640)
         (height 480))

    (unwind-protect
        (progn
          ;; --- Create WebGPU instance ---
          (setf instance (wgpu-create-instance (null-pointer)))
          (when (null-pointer-p instance)
            (error "Failed to create WebGPU instance"))
          (format t "Instance created~%")

          ;; --- Request adapter ---
          (let ((adapter-options (foreign-alloc '(:struct wgpu-request-adapter-options))))
            (setf (foreign-slot-value adapter-options '(:struct wgpu-request-adapter-options) 'next-in-chain)
                  (null-pointer))
            (setf (foreign-slot-value adapter-options '(:struct wgpu-request-adapter-options) 'feature-level)
                  0) ; WGPUFeatureLevel_Undefined
            (setf (foreign-slot-value adapter-options '(:struct wgpu-request-adapter-options) 'power-preference)
                  0) ; WGPUPowerPreference_Undefined
            (setf (foreign-slot-value adapter-options '(:struct wgpu-request-adapter-options) 'force-fallback-adapter)
                  0)
            (setf (foreign-slot-value adapter-options '(:struct wgpu-request-adapter-options) 'backend-type)
                  0) ; WGPUBackendType_Undefined
            (setf (foreign-slot-value adapter-options '(:struct wgpu-request-adapter-options) 'compatible-surface)
                  (null-pointer))

            (with-foreign-object (out-adapter 'wgpu-adapter)
              (let ((status (wgpu-shim-instance-request-adapter-sync instance adapter-options out-adapter)))
                (foreign-free adapter-options)
                (when (not (eq status :success)) ; WGPURequestAdapterStatus_Success
                  (error "Failed to request adapter: status=~a" status))
                (setf adapter (mem-ref out-adapter 'wgpu-adapter))
                (format t "Adapter obtained~%"))))

          ;; --- Request device ---
          (let ((device-desc (foreign-alloc '(:struct wgpu-device-descriptor))))
            (setf (foreign-slot-value device-desc '(:struct wgpu-device-descriptor) 'next-in-chain)
                  (null-pointer))
            (set-string-view (foreign-slot-pointer device-desc '(:struct wgpu-device-descriptor) 'label) nil)
            (setf (foreign-slot-value device-desc '(:struct wgpu-device-descriptor) 'required-feature-count)
                  0)
            (setf (foreign-slot-value device-desc '(:struct wgpu-device-descriptor) 'required-features)
                  (null-pointer))
            (setf (foreign-slot-value device-desc '(:struct wgpu-device-descriptor) 'required-limits)
                  (null-pointer))
            ;; default-queue
            (let ((queue-desc-ptr (foreign-slot-pointer device-desc '(:struct wgpu-device-descriptor) 'default-queue)))
              (setf (foreign-slot-value queue-desc-ptr '(:struct wgpu-queue-descriptor) 'next-in-chain) (null-pointer))
              (set-string-view (foreign-slot-pointer queue-desc-ptr '(:struct wgpu-queue-descriptor) 'label) nil))
            ;; device-lost-callback-info
            (let ((cb-ptr (foreign-slot-pointer device-desc '(:struct wgpu-device-descriptor) 'device-lost-callback-info)))
              (setf (foreign-slot-value cb-ptr '(:struct wgpu-device-lost-callback-info) 'next-in-chain) (null-pointer))
              (setf (foreign-slot-value cb-ptr '(:struct wgpu-device-lost-callback-info) 'mode) 0)
              (setf (foreign-slot-value cb-ptr '(:struct wgpu-device-lost-callback-info) 'callback) (null-pointer))
              (setf (foreign-slot-value cb-ptr '(:struct wgpu-device-lost-callback-info) 'userdata1) (null-pointer))
              (setf (foreign-slot-value cb-ptr '(:struct wgpu-device-lost-callback-info) 'userdata2) (null-pointer)))
            ;; uncaptured-error-callback-info (use silent handler to avoid panic)
            (let ((cb-ptr (foreign-slot-pointer device-desc '(:struct wgpu-device-descriptor) 'uncaptured-error-callback-info)))
              (setf (foreign-slot-value cb-ptr '(:struct wgpu-uncaptured-error-callback-info) 'next-in-chain) (null-pointer))
              (setf (foreign-slot-value cb-ptr '(:struct wgpu-uncaptured-error-callback-info) 'callback)
                    (%get-silent-uncaptured-error-callback))
              (setf (foreign-slot-value cb-ptr '(:struct wgpu-uncaptured-error-callback-info) 'userdata1) (null-pointer))
              (setf (foreign-slot-value cb-ptr '(:struct wgpu-uncaptured-error-callback-info) 'userdata2) (null-pointer)))

            (with-foreign-object (out-device 'wgpu-device)
              (let ((status (wgpu-shim-adapter-request-device-sync instance adapter device-desc out-device)))
                (foreign-free device-desc)
                (when (not (eq status :success)) ; WGPURequestDeviceStatus_Success
                  (error "Failed to request device: status=~a" status))
                (setf device (mem-ref out-device 'wgpu-device))
                (format t "Device obtained~%"))))

          ;; --- Create surface ---
          (setf surface (cl-webgpu/glfw:glfw-create-window-wgpu-surface instance window))
          (when (null-pointer-p surface)
            (error "Failed to create surface"))
          (format t "Surface created~%")

          ;; --- Get surface capabilities ---
          (let ((capabilities (foreign-alloc '(:struct wgpu-surface-capabilities))))
            (wgpu-surface-get-capabilities surface adapter capabilities)
            (let* ((format-count (foreign-slot-value capabilities '(:struct wgpu-surface-capabilities) 'format-count))
                   (formats (foreign-slot-value capabilities '(:struct wgpu-surface-capabilities) 'formats))
                   (surface-format (if (> format-count 0)
                                      (mem-ref formats 'wgpu-texture-format)
                                      :bgra8-unorm)))
              (format t "Surface format: ~a (~a formats available)~%" surface-format format-count)
              (wgpu-shim-surface-capabilities-free-members capabilities)
              (foreign-free capabilities)

              ;; --- Create shader modules ---
              (let ((vertex-shader (create-shader-module device *vertex-shader-wgsl* "Vertex Shader"))
                    (fragment-shader (create-shader-module device *fragment-shader-wgsl* "Fragment Shader")))

                ;; --- Create render pipeline ---
                (let ((pipeline-desc (foreign-alloc '(:struct wgpu-render-pipeline-descriptor)))
                      (entry-point-ptr (foreign-string-alloc "main")))

                  ;; Initialize pipeline descriptor
                  (setf (foreign-slot-value pipeline-desc '(:struct wgpu-render-pipeline-descriptor) 'next-in-chain)
                        (null-pointer))
                  (set-string-view (foreign-slot-pointer pipeline-desc '(:struct wgpu-render-pipeline-descriptor) 'label) nil)
                  (setf (foreign-slot-value pipeline-desc '(:struct wgpu-render-pipeline-descriptor) 'layout)
                        (null-pointer))

                  ;; Vertex state (inline in descriptor)
                  (let ((vertex-ptr (foreign-slot-pointer pipeline-desc '(:struct wgpu-render-pipeline-descriptor) 'vertex)))
                    (setf (foreign-slot-value vertex-ptr '(:struct wgpu-vertex-state) 'next-in-chain) (null-pointer))
                    (setf (foreign-slot-value vertex-ptr '(:struct wgpu-vertex-state) 'module) vertex-shader)
                    (let ((ep-ptr (foreign-slot-pointer vertex-ptr '(:struct wgpu-vertex-state) 'entry-point)))
                      (setf (foreign-slot-value ep-ptr '(:struct wgpu-string-view) 'data) entry-point-ptr)
                      (setf (foreign-slot-value ep-ptr '(:struct wgpu-string-view) 'length) 4))
                    (setf (foreign-slot-value vertex-ptr '(:struct wgpu-vertex-state) 'constant-count) 0)
                    (setf (foreign-slot-value vertex-ptr '(:struct wgpu-vertex-state) 'constants) (null-pointer))
                    (setf (foreign-slot-value vertex-ptr '(:struct wgpu-vertex-state) 'buffer-count) 0)
                    (setf (foreign-slot-value vertex-ptr '(:struct wgpu-vertex-state) 'buffers) (null-pointer)))

                  ;; Primitive state (inline in descriptor)
                  (let ((prim-ptr (foreign-slot-pointer pipeline-desc '(:struct wgpu-render-pipeline-descriptor) 'primitive)))
                    (setf (foreign-slot-value prim-ptr '(:struct wgpu-primitive-state) 'next-in-chain) (null-pointer))
                    (setf (foreign-slot-value prim-ptr '(:struct wgpu-primitive-state) 'topology) :triangle-list)
                    (setf (foreign-slot-value prim-ptr '(:struct wgpu-primitive-state) 'strip-index-format) :undefined)
                    (setf (foreign-slot-value prim-ptr '(:struct wgpu-primitive-state) 'front-face) :ccw)
                    (setf (foreign-slot-value prim-ptr '(:struct wgpu-primitive-state) 'cull-mode) :none)
                    (setf (foreign-slot-value prim-ptr '(:struct wgpu-primitive-state) 'unclipped-depth) 0))

                  ;; Depth/stencil (null)
                  (setf (foreign-slot-value pipeline-desc '(:struct wgpu-render-pipeline-descriptor) 'depth-stencil)
                        (null-pointer))

                  ;; Multisample state (inline in descriptor)
                  (let ((ms-ptr (foreign-slot-pointer pipeline-desc '(:struct wgpu-render-pipeline-descriptor) 'multisample)))
                    (setf (foreign-slot-value ms-ptr '(:struct wgpu-multisample-state) 'next-in-chain) (null-pointer))
                    (setf (foreign-slot-value ms-ptr '(:struct wgpu-multisample-state) 'count) 1)
                    (setf (foreign-slot-value ms-ptr '(:struct wgpu-multisample-state) 'mask) #xFFFFFFFF)
                    (setf (foreign-slot-value ms-ptr '(:struct wgpu-multisample-state) 'alpha-to-coverage-enabled) 0))

                  ;; Fragment state (separate allocation)
                  (let ((fragment-state (foreign-alloc '(:struct wgpu-fragment-state)))
                        (color-target (foreign-alloc '(:struct wgpu-color-target-state))))

                    ;; Color target
                    (setf (foreign-slot-value color-target '(:struct wgpu-color-target-state) 'next-in-chain) (null-pointer))
                    (setf (foreign-slot-value color-target '(:struct wgpu-color-target-state) 'format) surface-format)
                    (setf (foreign-slot-value color-target '(:struct wgpu-color-target-state) 'blend) (null-pointer))
                    (setf (foreign-slot-value color-target '(:struct wgpu-color-target-state) 'write-mask) #xF)

                    ;; Fragment state
                    (setf (foreign-slot-value fragment-state '(:struct wgpu-fragment-state) 'next-in-chain) (null-pointer))
                    (setf (foreign-slot-value fragment-state '(:struct wgpu-fragment-state) 'module) fragment-shader)
                    (let ((ep-ptr (foreign-slot-pointer fragment-state '(:struct wgpu-fragment-state) 'entry-point)))
                      (setf (foreign-slot-value ep-ptr '(:struct wgpu-string-view) 'data) entry-point-ptr)
                      (setf (foreign-slot-value ep-ptr '(:struct wgpu-string-view) 'length) 4))
                    (setf (foreign-slot-value fragment-state '(:struct wgpu-fragment-state) 'constant-count) 0)
                    (setf (foreign-slot-value fragment-state '(:struct wgpu-fragment-state) 'constants) (null-pointer))
                    (setf (foreign-slot-value fragment-state '(:struct wgpu-fragment-state) 'target-count) 1)
                    (setf (foreign-slot-value fragment-state '(:struct wgpu-fragment-state) 'targets) color-target)

                    (setf (foreign-slot-value pipeline-desc '(:struct wgpu-render-pipeline-descriptor) 'fragment)
                          fragment-state)

                      (setf pipeline (wgpu-device-create-render-pipeline device pipeline-desc))
                      (when (null-pointer-p pipeline)
                        (error "Pipeline creation returned null"))

                    ;; Configure surface
                    (let ((config (foreign-alloc '(:struct wgpu-surface-configuration))))
                      (setf (foreign-slot-value config '(:struct wgpu-surface-configuration) 'next-in-chain) (null-pointer))
                      (setf (foreign-slot-value config '(:struct wgpu-surface-configuration) 'device) device)
                      (setf (foreign-slot-value config '(:struct wgpu-surface-configuration) 'format) surface-format)
                      (setf (foreign-slot-value config '(:struct wgpu-surface-configuration) 'usage)
                            +wgpu-texture-usage-render-attachment+)
                      (setf (foreign-slot-value config '(:struct wgpu-surface-configuration) 'width) width)
                      (setf (foreign-slot-value config '(:struct wgpu-surface-configuration) 'height) height)
                      (setf (foreign-slot-value config '(:struct wgpu-surface-configuration) 'view-format-count) 0)
                      (setf (foreign-slot-value config '(:struct wgpu-surface-configuration) 'view-formats) (null-pointer))
                      (setf (foreign-slot-value config '(:struct wgpu-surface-configuration) 'alpha-mode) 1) ; Opaque
                      (setf (foreign-slot-value config '(:struct wgpu-surface-configuration) 'present-mode) 1) ; FIFO
                      (wgpu-surface-configure surface config)
                      (foreign-free config)
                      (format t "Surface configured~%"))

                    ;; --- Render loop ---
                    (format t "Starting render loop (close window to exit)...~%")
                    (loop while (not (cl-webgpu/glfw:window-should-close-p window))
                          do (progn
                               (cl-webgpu/glfw:poll-events)

                                ;; Get current texture
                                (with-foreign-object (surface-texture '(:struct wgpu-surface-texture))
                                  (wgpu-surface-get-current-texture surface surface-texture)
                                  (let ((texture (foreign-slot-value surface-texture '(:struct wgpu-surface-texture) 'texture))
                                        (status (mem-ref (foreign-slot-pointer surface-texture '(:struct wgpu-surface-texture) 'status) :uint32)))
                                     (when (and (not (null-pointer-p texture))
                                                (or (= status 1) (= status 2))) ; Success optimal or suboptimal
                                      ;; Create texture view
                                     (let* ((texture-view-desc (foreign-alloc '(:struct wgpu-texture-view-descriptor)))
                                            (texture-view nil))
                                       (setf (foreign-slot-value texture-view-desc '(:struct wgpu-texture-view-descriptor) 'next-in-chain) (null-pointer))
                                        (set-string-view (foreign-slot-pointer texture-view-desc '(:struct wgpu-texture-view-descriptor) 'label) nil)
                                       (setf (foreign-slot-value texture-view-desc '(:struct wgpu-texture-view-descriptor) 'format) surface-format)
                                       (setf (foreign-slot-value texture-view-desc '(:struct wgpu-texture-view-descriptor) 'dimension) 2) ; 2D
                                       (setf (foreign-slot-value texture-view-desc '(:struct wgpu-texture-view-descriptor) 'base-mip-level) 0)
                                       (setf (foreign-slot-value texture-view-desc '(:struct wgpu-texture-view-descriptor) 'mip-level-count) 1)
                                       (setf (foreign-slot-value texture-view-desc '(:struct wgpu-texture-view-descriptor) 'base-array-layer) 0)
                                       (setf (foreign-slot-value texture-view-desc '(:struct wgpu-texture-view-descriptor) 'array-layer-count) 1)
                                       (setf (foreign-slot-value texture-view-desc '(:struct wgpu-texture-view-descriptor) 'aspect) 1) ; All
                                       (setf (foreign-slot-value texture-view-desc '(:struct wgpu-texture-view-descriptor) 'usage) 0)
                                       (setf texture-view (wgpu-texture-create-view texture texture-view-desc))
                                       (foreign-free texture-view-desc)

                                       ;; Create command encoder
                                       (let* ((encoder-desc (foreign-alloc '(:struct wgpu-command-encoder-descriptor)))
                                              (encoder nil))
                                         (setf (foreign-slot-value encoder-desc '(:struct wgpu-command-encoder-descriptor) 'next-in-chain) (null-pointer))
                                          (set-string-view (foreign-slot-pointer encoder-desc '(:struct wgpu-command-encoder-descriptor) 'label) nil)
                                         (setf encoder (wgpu-device-create-command-encoder device encoder-desc))
                                         (foreign-free encoder-desc)

                                         ;; Begin render pass
                                         (let* ((render-pass-desc (foreign-alloc '(:struct wgpu-render-pass-descriptor)))
                                                (color-attachment (foreign-alloc '(:struct wgpu-render-pass-color-attachment))))

                                           ;; Color attachment
                                           (setf (foreign-slot-value color-attachment '(:struct wgpu-render-pass-color-attachment) 'next-in-chain) (null-pointer))
                                           (setf (foreign-slot-value color-attachment '(:struct wgpu-render-pass-color-attachment) 'view) texture-view)
                                           (setf (foreign-slot-value color-attachment '(:struct wgpu-render-pass-color-attachment) 'depth-slice) #xFFFFFFFF) ; WGPU_DEPTH_SLICE_UNDEFINED
                                           (setf (foreign-slot-value color-attachment '(:struct wgpu-render-pass-color-attachment) 'resolve-target) (null-pointer))
                                           (setf (foreign-slot-value color-attachment '(:struct wgpu-render-pass-color-attachment) 'load-op) :clear)
                                           (setf (foreign-slot-value color-attachment '(:struct wgpu-render-pass-color-attachment) 'store-op) :store)
                                           (let ((clear-color-ptr (foreign-slot-pointer color-attachment '(:struct wgpu-render-pass-color-attachment) 'clear-value)))
                                             (setf (foreign-slot-value clear-color-ptr '(:struct wgpu-color) 'r) 0.1d0)
                                             (setf (foreign-slot-value clear-color-ptr '(:struct wgpu-color) 'g) 0.1d0)
                                             (setf (foreign-slot-value clear-color-ptr '(:struct wgpu-color) 'b) 0.3d0)
                                             (setf (foreign-slot-value clear-color-ptr '(:struct wgpu-color) 'a) 1.0d0))

                                           ;; Render pass descriptor
                                           (setf (foreign-slot-value render-pass-desc '(:struct wgpu-render-pass-descriptor) 'next-in-chain) (null-pointer))
                                            (set-string-view (foreign-slot-pointer render-pass-desc '(:struct wgpu-render-pass-descriptor) 'label) nil)
                                           (setf (foreign-slot-value render-pass-desc '(:struct wgpu-render-pass-descriptor) 'color-attachment-count) 1)
                                           (setf (foreign-slot-value render-pass-desc '(:struct wgpu-render-pass-descriptor) 'color-attachments) color-attachment)
                                           (setf (foreign-slot-value render-pass-desc '(:struct wgpu-render-pass-descriptor) 'depth-stencil-attachment) (null-pointer))
                                           (setf (foreign-slot-value render-pass-desc '(:struct wgpu-render-pass-descriptor) 'occlusion-query-set) (null-pointer))
                                           (setf (foreign-slot-value render-pass-desc '(:struct wgpu-render-pass-descriptor) 'timestamp-writes) (null-pointer))

                                            (let ((render-pass (wgpu-command-encoder-begin-render-pass encoder render-pass-desc)))
                                              (wgpu-render-pass-encoder-set-pipeline render-pass pipeline)
                                              (wgpu-render-pass-encoder-draw render-pass 3 1 0 0)
                                              (wgpu-render-pass-encoder-end render-pass)
                                              (wgpu-render-pass-encoder-release render-pass))

                                           (foreign-free render-pass-desc)
                                           (foreign-free color-attachment)

                                           ;; Finish encoding and submit
                                           (let* ((cmd-buffer-desc (foreign-alloc '(:struct wgpu-command-buffer-descriptor)))
                                                  (cmd-buffer nil))
                                             (setf (foreign-slot-value cmd-buffer-desc '(:struct wgpu-command-buffer-descriptor) 'next-in-chain) (null-pointer))
                                              (set-string-view (foreign-slot-pointer cmd-buffer-desc '(:struct wgpu-command-buffer-descriptor) 'label) nil)
                                             (setf cmd-buffer (wgpu-command-encoder-finish encoder cmd-buffer-desc))
                                             (foreign-free cmd-buffer-desc)

                                             (let ((queue (wgpu-device-get-queue device)))
                                               (with-foreign-object (buffers 'wgpu-command-buffer 1)
                                                 (setf (mem-aref buffers 'wgpu-command-buffer 0) cmd-buffer)
                                                 (wgpu-queue-submit queue 1 buffers))
                                               (wgpu-command-buffer-release cmd-buffer))

                                             ;; Present
                                             (wgpu-surface-present surface)

                                             (wgpu-command-encoder-release encoder))

                                           (wgpu-texture-view-release texture-view)))))))

                               ;; Small delay
                               (sleep 0.016)))

                    ;; Cleanup pipeline resources
                    (foreign-free pipeline-desc)
                    (foreign-free entry-point-ptr)
                    (foreign-free fragment-state)
                    (foreign-free color-target)

                    (wgpu-render-pipeline-release pipeline)
                    (wgpu-shader-module-release vertex-shader)
                    (wgpu-shader-module-release fragment-shader))

          ;; --- Cleanup ---
          (format t "Cleaning up...~%")
          (wgpu-surface-unconfigure surface)
          (wgpu-surface-release surface)
          (wgpu-device-release device)
          (wgpu-adapter-release adapter)
          (wgpu-instance-release instance))

      ;; Always cleanup GLFW
      (cl-webgpu/glfw:destroy-window window)
      (cl-webgpu/glfw:terminate)
      (format t "Done.~%"))))))))

;; Run the example
(run-triangle-example)
