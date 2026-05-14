(in-package #:cl-webgpu/wrapper)

;;;; -------------------------------------------------------------------------
;;;; Base CLOS handle
;;;; -------------------------------------------------------------------------

(defclass gpu-handle ()
  ((handle :initarg :handle :accessor handle)))

(defgeneric release (obj)
  (:documentation "Release/free a GPU handle, calling the appropriate wgpu release function."))

(defmethod null-handle-p ((obj gpu-handle))
  (null-pointer-p (handle obj)))

(defmethod print-object ((obj gpu-handle) stream)
  (print-unreadable-object (obj stream :type t)
    (format stream "~a" (handle obj))))


;;;; -------------------------------------------------------------------------
;;;; Concrete handle classes
;;;; -------------------------------------------------------------------------

(defclass gpu-instance       (gpu-handle) ())
(defclass gpu-adapter        (gpu-handle) ())
(defclass gpu-device         (gpu-handle) ())
(defclass gpu-surface        (gpu-handle) ())
(defclass gpu-shader-module  (gpu-handle) ())
(defclass gpu-render-pipeline (gpu-handle) ())
(defclass gpu-command-encoder (gpu-handle) ())
(defclass gpu-render-pass    (gpu-handle) ())
(defclass gpu-texture-view   (gpu-handle) ())
(defclass gpu-queue          (gpu-handle) ())
(defclass gpu-buffer         (gpu-handle) ())

(defmethod release ((obj gpu-instance))        (wgpu-instance-release       (handle obj)))
(defmethod release ((obj gpu-adapter))         (wgpu-adapter-release        (handle obj)))
(defmethod release ((obj gpu-device))          (wgpu-device-release         (handle obj)))
(defmethod release ((obj gpu-surface))
  (wgpu-surface-unconfigure (handle obj))
  (wgpu-surface-release     (handle obj)))
(defmethod release ((obj gpu-shader-module))   (wgpu-shader-module-release  (handle obj)))
(defmethod release ((obj gpu-render-pipeline)) (wgpu-render-pipeline-release (handle obj)))
(defmethod release ((obj gpu-command-encoder)) (wgpu-command-encoder-release (handle obj)))
(defmethod release ((obj gpu-render-pass))     (wgpu-render-pass-encoder-release (handle obj)))
(defmethod release ((obj gpu-texture-view))    (wgpu-texture-view-release   (handle obj)))
(defmethod release ((obj gpu-queue))           (wgpu-queue-release          (handle obj)))
(defmethod release ((obj gpu-buffer))
  (wgpu-buffer-destroy (handle obj))
  (wgpu-buffer-release (handle obj)))


;;;; -------------------------------------------------------------------------
;;;; Utility: scoped zeroed foreign struct
;;;; -------------------------------------------------------------------------

(defmacro with-wgpu-struct ((var type) &body body)
  "Bind VAR to a zeroed foreign struct of TYPE, freeing it on exit."
  `(with-foreign-object (,var ,type)
     (foreign-funcall "memset" :pointer ,var :int 0
                      :size (foreign-type-size ,type) :void)
     ,@body))

(defun %set-string-view (ptr string)
  "Fill a WGPUStringView at PTR from STRING. Returns allocated data pointer or NIL."
  (if (and string (plusp (length string)))
      (let ((data (foreign-string-alloc string)))
        (setf (foreign-slot-value ptr '(:struct wgpu-string-view) 'data) data
              (foreign-slot-value ptr '(:struct wgpu-string-view) 'length) (length string))
        data)
      (progn
        (setf (foreign-slot-value ptr '(:struct wgpu-string-view) 'data) (null-pointer)
              (foreign-slot-value ptr '(:struct wgpu-string-view) 'length) 0)
        nil)))


;;;; -------------------------------------------------------------------------
;;;; with-X macros
;;;; -------------------------------------------------------------------------

(defmacro with-gpu-instance ((var) &body body)
  `(let ((,var (make-gpu-instance)))
     (unwind-protect (progn ,@body)
       (release ,var))))

(defmacro with-gpu-adapter ((var instance &rest options) &body body)
  `(let ((,var (request-gpu-adapter ,instance ,@options)))
     (unwind-protect (progn ,@body)
       (release ,var))))

(defmacro with-gpu-device ((var instance adapter &rest options) &body body)
  `(let ((,var (request-gpu-device ,instance ,adapter ,@options)))
     (unwind-protect (progn ,@body)
       (release ,var))))

(defmacro with-gpu-shader-module ((var device source &rest options) &body body)
  `(let ((,var (make-shader-module ,device ,source ,@options)))
     (unwind-protect (progn ,@body)
       (release ,var))))

(defmacro with-gpu-render-pipeline ((var device &rest options) &body body)
  `(let ((,var (make-render-pipeline ,device ,@options)))
     (unwind-protect (progn ,@body)
       (release ,var))))

(defmacro with-gpu-command-encoder ((var device &rest options) &body body)
  `(let ((,var (make-command-encoder ,device ,@options)))
     (unwind-protect (progn ,@body)
       (release ,var))))

(defmacro with-render-pass ((var encoder texture-view &rest options) &body body)
  `(let ((,var (begin-render-pass ,encoder ,texture-view ,@options)))
     (unwind-protect (progn ,@body)
       (release ,var))))


;;;; -------------------------------------------------------------------------
;;;; Creation helpers
;;;; -------------------------------------------------------------------------

(defun make-gpu-instance ()
  "Create a new WGPUInstance."
  (let ((ptr (wgpu-create-instance (null-pointer))))
    (when (null-pointer-p ptr)
      (error "Failed to create WGPUInstance"))
    (make-instance 'gpu-instance :handle ptr)))

(defun request-gpu-adapter (instance &key power-preference backend compatible-surface)
  "Request a WGPUAdapter synchronously. Returns a GPU-ADAPTER."
  (with-wgpu-struct (opts '(:struct wgpu-request-adapter-options))
    (setf (foreign-slot-value opts '(:struct wgpu-request-adapter-options) 'next-in-chain)
          (null-pointer)
          (foreign-slot-value opts '(:struct wgpu-request-adapter-options) 'feature-level)
          0
          (foreign-slot-value opts '(:struct wgpu-request-adapter-options) 'power-preference)
          (or power-preference 0)
          (foreign-slot-value opts '(:struct wgpu-request-adapter-options) 'force-fallback-adapter)
          0
          (foreign-slot-value opts '(:struct wgpu-request-adapter-options) 'backend-type)
          (or backend 0)
          (foreign-slot-value opts '(:struct wgpu-request-adapter-options) 'compatible-surface)
          (or compatible-surface (null-pointer)))
    (with-foreign-object (out 'wgpu-adapter)
      (let ((status (wgpu-shim-instance-request-adapter-sync
                     (handle instance) opts out)))
        (unless (eq status :success)
          (error "Failed to request adapter: ~a" status))
        (make-instance 'gpu-adapter :handle (mem-ref out 'wgpu-adapter))))))

(defun request-gpu-device (instance adapter &key label)
  "Request a WGPUDevice synchronously. Returns a GPU-DEVICE."
  (with-wgpu-struct (desc '(:struct wgpu-device-descriptor))
    (setf (foreign-slot-value desc '(:struct wgpu-device-descriptor) 'next-in-chain) (null-pointer))
    (%set-string-view (foreign-slot-pointer desc '(:struct wgpu-device-descriptor) 'label) label)
    (setf (foreign-slot-value desc '(:struct wgpu-device-descriptor) 'required-feature-count) 0
          (foreign-slot-value desc '(:struct wgpu-device-descriptor) 'required-features) (null-pointer)
          (foreign-slot-value desc '(:struct wgpu-device-descriptor) 'required-limits) (null-pointer))
    (let ((q (foreign-slot-pointer desc '(:struct wgpu-device-descriptor) 'default-queue)))
      (setf (foreign-slot-value q '(:struct wgpu-queue-descriptor) 'next-in-chain) (null-pointer))
      (%set-string-view (foreign-slot-pointer q '(:struct wgpu-queue-descriptor) 'label) nil))
    (let ((dlc (foreign-slot-pointer desc '(:struct wgpu-device-descriptor) 'device-lost-callback-info)))
      (setf (foreign-slot-value dlc '(:struct wgpu-device-lost-callback-info) 'next-in-chain) (null-pointer)
            (foreign-slot-value dlc '(:struct wgpu-device-lost-callback-info) 'mode) 0
            (foreign-slot-value dlc '(:struct wgpu-device-lost-callback-info) 'callback) (null-pointer)
            (foreign-slot-value dlc '(:struct wgpu-device-lost-callback-info) 'userdata1) (null-pointer)
            (foreign-slot-value dlc '(:struct wgpu-device-lost-callback-info) 'userdata2) (null-pointer)))
    (let ((uec (foreign-slot-pointer desc '(:struct wgpu-device-descriptor) 'uncaptured-error-callback-info)))
      (setf (foreign-slot-value uec '(:struct wgpu-uncaptured-error-callback-info) 'next-in-chain) (null-pointer)
            (foreign-slot-value uec '(:struct wgpu-uncaptured-error-callback-info) 'callback)
            (%get-silent-uncaptured-error-callback)
            (foreign-slot-value uec '(:struct wgpu-uncaptured-error-callback-info) 'userdata1) (null-pointer)
            (foreign-slot-value uec '(:struct wgpu-uncaptured-error-callback-info) 'userdata2) (null-pointer)))
    (with-foreign-object (out 'wgpu-device)
      (let ((status (wgpu-shim-adapter-request-device-sync
                     (handle instance) (handle adapter) desc out)))
        (unless (eq status :success)
          (error "Failed to request device: ~a" status))
        (make-instance 'gpu-device :handle (mem-ref out 'wgpu-device))))))

(defun make-shader-module (device wgsl-source &key label)
  "Compile a WGSL shader from SOURCE-STRING. Returns a GPU-SHADER-MODULE."
  (let ((shader-source (foreign-alloc '(:struct wgpu-shader-source-wgsl)))
        (descriptor    (foreign-alloc '(:struct wgpu-shader-module-descriptor)))
        (code-data nil)
        (label-data nil))
    (unwind-protect
        (progn
          (let ((chain (foreign-slot-pointer shader-source '(:struct wgpu-shader-source-wgsl) 'chain)))
            (setf (foreign-slot-value chain '(:struct wgpu-chained-struct) 'next) (null-pointer)
                  (foreign-slot-value chain '(:struct wgpu-chained-struct) 's-type) 2)) ; WGPUSType_ShaderSourceWGSL
          (setf code-data
                (%set-string-view
                 (foreign-slot-pointer shader-source '(:struct wgpu-shader-source-wgsl) 'code)
                 wgsl-source))
          (setf (foreign-slot-value descriptor '(:struct wgpu-shader-module-descriptor) 'next-in-chain)
                (foreign-slot-pointer shader-source '(:struct wgpu-shader-source-wgsl) 'chain))
          (setf label-data
                (%set-string-view
                 (foreign-slot-pointer descriptor '(:struct wgpu-shader-module-descriptor) 'label)
                 label))
          (let ((ptr (wgpu-device-create-shader-module (handle device) descriptor)))
            (when (null-pointer-p ptr)
              (error "Failed to create shader module"))
            (make-instance 'gpu-shader-module :handle ptr)))
      (when code-data  (foreign-free code-data))
      (when label-data (foreign-free label-data))
      (foreign-free descriptor)
      (foreign-free shader-source))))

(defun get-surface-format (surface adapter)
  "Query the preferred texture format for SURFACE + ADAPTER."
  (with-wgpu-struct (caps '(:struct wgpu-surface-capabilities))
    (wgpu-surface-get-capabilities (handle surface) (handle adapter) caps)
    (let* ((count (foreign-slot-value caps '(:struct wgpu-surface-capabilities) 'format-count))
           (formats (foreign-slot-value caps '(:struct wgpu-surface-capabilities) 'formats))
           (fmt (if (plusp count)
                    (mem-ref formats 'wgpu-texture-format)
                    :bgra8-unorm)))
      (wgpu-shim-surface-capabilities-free-members caps)
      fmt)))

(defun make-render-pipeline (device &key vertex-module fragment-module
                                         (entry-point "main")
                                         surface-format
                                         label)
  "Build a simple render pipeline (no depth, no vertex buffers). Returns GPU-RENDER-PIPELINE."
  (let ((desc         (foreign-alloc '(:struct wgpu-render-pipeline-descriptor)))
        (frag-state   (foreign-alloc '(:struct wgpu-fragment-state)))
        (color-target (foreign-alloc '(:struct wgpu-color-target-state)))
        (ep-data      (foreign-string-alloc entry-point))
        (ep-len       (length entry-point)))
    (unwind-protect
        (progn
          (setf (foreign-slot-value desc '(:struct wgpu-render-pipeline-descriptor) 'next-in-chain)
                (null-pointer))
          (%set-string-view (foreign-slot-pointer desc '(:struct wgpu-render-pipeline-descriptor) 'label) label)
          (setf (foreign-slot-value desc '(:struct wgpu-render-pipeline-descriptor) 'layout)
                (null-pointer))

          ;; vertex state
          (let ((v (foreign-slot-pointer desc '(:struct wgpu-render-pipeline-descriptor) 'vertex)))
            (setf (foreign-slot-value v '(:struct wgpu-vertex-state) 'next-in-chain) (null-pointer)
                  (foreign-slot-value v '(:struct wgpu-vertex-state) 'module) (handle vertex-module))
            (let ((ep (foreign-slot-pointer v '(:struct wgpu-vertex-state) 'entry-point)))
              (setf (foreign-slot-value ep '(:struct wgpu-string-view) 'data) ep-data
                    (foreign-slot-value ep '(:struct wgpu-string-view) 'length) ep-len))
            (setf (foreign-slot-value v '(:struct wgpu-vertex-state) 'constant-count) 0
                  (foreign-slot-value v '(:struct wgpu-vertex-state) 'constants) (null-pointer)
                  (foreign-slot-value v '(:struct wgpu-vertex-state) 'buffer-count) 0
                  (foreign-slot-value v '(:struct wgpu-vertex-state) 'buffers) (null-pointer)))

          ;; primitive state
          (let ((p (foreign-slot-pointer desc '(:struct wgpu-render-pipeline-descriptor) 'primitive)))
            (setf (foreign-slot-value p '(:struct wgpu-primitive-state) 'next-in-chain) (null-pointer)
                  (foreign-slot-value p '(:struct wgpu-primitive-state) 'topology) :triangle-list
                  (foreign-slot-value p '(:struct wgpu-primitive-state) 'strip-index-format) :undefined
                  (foreign-slot-value p '(:struct wgpu-primitive-state) 'front-face) :ccw
                  (foreign-slot-value p '(:struct wgpu-primitive-state) 'cull-mode) :none
                  (foreign-slot-value p '(:struct wgpu-primitive-state) 'unclipped-depth) 0))

          ;; no depth/stencil
          (setf (foreign-slot-value desc '(:struct wgpu-render-pipeline-descriptor) 'depth-stencil)
                (null-pointer))

          ;; multisample state
          (let ((ms (foreign-slot-pointer desc '(:struct wgpu-render-pipeline-descriptor) 'multisample)))
            (setf (foreign-slot-value ms '(:struct wgpu-multisample-state) 'next-in-chain) (null-pointer)
                  (foreign-slot-value ms '(:struct wgpu-multisample-state) 'count) 1
                  (foreign-slot-value ms '(:struct wgpu-multisample-state) 'mask) #xFFFFFFFF
                  (foreign-slot-value ms '(:struct wgpu-multisample-state) 'alpha-to-coverage-enabled) 0))

          ;; color target
          (setf (foreign-slot-value color-target '(:struct wgpu-color-target-state) 'next-in-chain)
                (null-pointer)
                (foreign-slot-value color-target '(:struct wgpu-color-target-state) 'format)
                (or surface-format :bgra8-unorm)
                (foreign-slot-value color-target '(:struct wgpu-color-target-state) 'blend)
                (null-pointer)
                (foreign-slot-value color-target '(:struct wgpu-color-target-state) 'write-mask)
                #xF)

          ;; fragment state
          (setf (foreign-slot-value frag-state '(:struct wgpu-fragment-state) 'next-in-chain)
                (null-pointer)
                (foreign-slot-value frag-state '(:struct wgpu-fragment-state) 'module)
                (handle fragment-module))
          (let ((ep (foreign-slot-pointer frag-state '(:struct wgpu-fragment-state) 'entry-point)))
            (setf (foreign-slot-value ep '(:struct wgpu-string-view) 'data) ep-data
                  (foreign-slot-value ep '(:struct wgpu-string-view) 'length) ep-len))
          (setf (foreign-slot-value frag-state '(:struct wgpu-fragment-state) 'constant-count) 0
                (foreign-slot-value frag-state '(:struct wgpu-fragment-state) 'constants) (null-pointer)
                (foreign-slot-value frag-state '(:struct wgpu-fragment-state) 'target-count) 1
                (foreign-slot-value frag-state '(:struct wgpu-fragment-state) 'targets) color-target)

          (setf (foreign-slot-value desc '(:struct wgpu-render-pipeline-descriptor) 'fragment)
                frag-state)

          (let ((ptr (wgpu-device-create-render-pipeline (handle device) desc)))
            (when (null-pointer-p ptr)
              (error "Failed to create render pipeline"))
            (make-instance 'gpu-render-pipeline :handle ptr)))
      (foreign-free ep-data)
      (foreign-free frag-state)
      (foreign-free color-target)
      (foreign-free desc))))

(defun configure-surface (surface device format width height)
  "Configure SURFACE for rendering. Call once after device creation."
  (with-wgpu-struct (cfg '(:struct wgpu-surface-configuration))
    (setf (foreign-slot-value cfg '(:struct wgpu-surface-configuration) 'next-in-chain) (null-pointer)
          (foreign-slot-value cfg '(:struct wgpu-surface-configuration) 'device) (handle device)
          (foreign-slot-value cfg '(:struct wgpu-surface-configuration) 'format) format
          (foreign-slot-value cfg '(:struct wgpu-surface-configuration) 'usage)
          +wgpu-texture-usage-render-attachment+
          (foreign-slot-value cfg '(:struct wgpu-surface-configuration) 'width) width
          (foreign-slot-value cfg '(:struct wgpu-surface-configuration) 'height) height
          (foreign-slot-value cfg '(:struct wgpu-surface-configuration) 'view-format-count) 0
          (foreign-slot-value cfg '(:struct wgpu-surface-configuration) 'view-formats) (null-pointer)
          (foreign-slot-value cfg '(:struct wgpu-surface-configuration) 'alpha-mode) 1 ; Opaque
          (foreign-slot-value cfg '(:struct wgpu-surface-configuration) 'present-mode) 1) ; FIFO
    (wgpu-surface-configure (handle surface) cfg)))

(defun make-command-encoder (device &key label)
  "Create a WGPUCommandEncoder. Returns a GPU-COMMAND-ENCODER."
  (with-wgpu-struct (desc '(:struct wgpu-command-encoder-descriptor))
    (setf (foreign-slot-value desc '(:struct wgpu-command-encoder-descriptor) 'next-in-chain)
          (null-pointer))
    (%set-string-view (foreign-slot-pointer desc '(:struct wgpu-command-encoder-descriptor) 'label) label)
    (let ((ptr (wgpu-device-create-command-encoder (handle device) desc)))
      (make-instance 'gpu-command-encoder :handle ptr))))

(defun begin-render-pass (encoder texture-view
                          &key (clear-r 0.0d0) (clear-g 0.0d0)
                               (clear-b 0.0d0) (clear-a 1.0d0))
  "Begin a render pass with a single colour attachment. Returns a GPU-RENDER-PASS.
The caller must call RELEASE on the returned pass or use WITH-RENDER-PASS."
  (let ((att  (foreign-alloc '(:struct wgpu-render-pass-color-attachment)))
        (desc (foreign-alloc '(:struct wgpu-render-pass-descriptor))))
    ;; colour attachment
    (setf (foreign-slot-value att '(:struct wgpu-render-pass-color-attachment) 'next-in-chain) (null-pointer)
          (foreign-slot-value att '(:struct wgpu-render-pass-color-attachment) 'view)
          (etypecase texture-view
            (gpu-texture-view (handle texture-view))
            (t texture-view))
          (foreign-slot-value att '(:struct wgpu-render-pass-color-attachment) 'depth-slice) #xFFFFFFFF
          (foreign-slot-value att '(:struct wgpu-render-pass-color-attachment) 'resolve-target) (null-pointer)
          (foreign-slot-value att '(:struct wgpu-render-pass-color-attachment) 'load-op) :clear
          (foreign-slot-value att '(:struct wgpu-render-pass-color-attachment) 'store-op) :store)
    (let ((cc (foreign-slot-pointer att '(:struct wgpu-render-pass-color-attachment) 'clear-value)))
      (setf (foreign-slot-value cc '(:struct wgpu-color) 'r) (float clear-r 1.0d0)
            (foreign-slot-value cc '(:struct wgpu-color) 'g) (float clear-g 1.0d0)
            (foreign-slot-value cc '(:struct wgpu-color) 'b) (float clear-b 1.0d0)
            (foreign-slot-value cc '(:struct wgpu-color) 'a) (float clear-a 1.0d0)))
    ;; pass descriptor
    (setf (foreign-slot-value desc '(:struct wgpu-render-pass-descriptor) 'next-in-chain) (null-pointer))
    (%set-string-view (foreign-slot-pointer desc '(:struct wgpu-render-pass-descriptor) 'label) nil)
    (setf (foreign-slot-value desc '(:struct wgpu-render-pass-descriptor) 'color-attachment-count) 1
          (foreign-slot-value desc '(:struct wgpu-render-pass-descriptor) 'color-attachments) att
          (foreign-slot-value desc '(:struct wgpu-render-pass-descriptor) 'depth-stencil-attachment) (null-pointer)
          (foreign-slot-value desc '(:struct wgpu-render-pass-descriptor) 'occlusion-query-set) (null-pointer)
          (foreign-slot-value desc '(:struct wgpu-render-pass-descriptor) 'timestamp-writes) (null-pointer))
    (let ((pass (wgpu-command-encoder-begin-render-pass (handle encoder) desc)))
      (foreign-free desc)
      (foreign-free att)
      (make-instance 'gpu-render-pass :handle pass))))

(defun end-and-submit (encoder pass queue surface)
  "End PASS, finish ENCODER, submit to QUEUE, and present SURFACE.
Releases the command buffer; does not release ENCODER, PASS, QUEUE, or SURFACE."
  (wgpu-render-pass-encoder-end (handle pass))
  (with-wgpu-struct (cmd-desc '(:struct wgpu-command-buffer-descriptor))
    (setf (foreign-slot-value cmd-desc '(:struct wgpu-command-buffer-descriptor) 'next-in-chain)
          (null-pointer))
    (%set-string-view (foreign-slot-pointer cmd-desc '(:struct wgpu-command-buffer-descriptor) 'label) nil)
    (let ((cmd-buf (wgpu-command-encoder-finish (handle encoder) cmd-desc)))
      (with-foreign-object (bufs 'wgpu-command-buffer 1)
        (setf (mem-aref bufs 'wgpu-command-buffer 0) cmd-buf)
        (wgpu-queue-submit (handle queue) 1 bufs))
      (wgpu-command-buffer-release cmd-buf)))
  (wgpu-surface-present (handle surface)))
