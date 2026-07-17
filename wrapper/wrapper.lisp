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
(defclass gpu-texture        (gpu-handle) ())

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
(defmethod release ((obj gpu-texture))
  (wgpu-texture-destroy (handle obj))
  (wgpu-texture-release (handle obj)))


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

(defun %build-vertex-buffer-layouts (layouts)
  "Allocate WGPUVertexBufferLayout[] and associated WGPUVertexAttribute[] arrays from
LAYOUTS, a list of plists each with keys:
  :array-stride  — byte stride (required)
  :step-mode     — :vertex (default) or :instance
  :attributes    — list of plists with :format, :offset, :shader-location

Returns (values layouts-ptr attr-ptrs n-layouts).
All returned pointers must be freed by the caller after pipeline creation."
  (let* ((n       (length layouts))
         (lptr    (foreign-alloc '(:struct wgpu-vertex-buffer-layout) :count n))
         (aptrs   '()))
    (loop for vbl in layouts
          for i from 0 do
          (let* ((attrs  (getf vbl :attributes))
                 (na     (length attrs))
                 (aptr   (if (plusp na)
                             (foreign-alloc '(:struct wgpu-vertex-attribute) :count na)
                             (null-pointer)))
                 (lp     (mem-aptr lptr '(:struct wgpu-vertex-buffer-layout) i)))
            (when (plusp na)
              (push aptr aptrs))
            ;; populate attributes
            (loop for attr in attrs
                  for j from 0 do
                  (let ((ap (mem-aptr aptr '(:struct wgpu-vertex-attribute) j)))
                    (setf (foreign-slot-value ap '(:struct wgpu-vertex-attribute) 'next-in-chain) (null-pointer)
                          (foreign-slot-value ap '(:struct wgpu-vertex-attribute) 'format)         (getf attr :format)
                          (foreign-slot-value ap '(:struct wgpu-vertex-attribute) 'offset)         (getf attr :offset 0)
                          (foreign-slot-value ap '(:struct wgpu-vertex-attribute) 'shader-location) (getf attr :shader-location 0))))
            ;; populate layout
            (setf (foreign-slot-value lp '(:struct wgpu-vertex-buffer-layout) 'next-in-chain)  (null-pointer)
                  (foreign-slot-value lp '(:struct wgpu-vertex-buffer-layout) 'step-mode)      (or (getf vbl :step-mode) :vertex)
                  (foreign-slot-value lp '(:struct wgpu-vertex-buffer-layout) 'array-stride)   (getf vbl :array-stride)
                  (foreign-slot-value lp '(:struct wgpu-vertex-buffer-layout) 'attribute-count) na
                  (foreign-slot-value lp '(:struct wgpu-vertex-buffer-layout) 'attributes)     aptr)))
    (values lptr (nreverse aptrs) n)))

(defun make-render-pipeline (device &key vertex-module fragment-module
                                         (entry-point "main")
                                         vertex-entry-point
                                         fragment-entry-point
                                         surface-format
                                         vertex-buffer-layouts
                                         (topology :triangle-list)
                                         depth-stencil-state
                                         blend
                                         label)
  "Build a render pipeline. Returns GPU-RENDER-PIPELINE.

TOPOLOGY selects the primitive assembly mode (default :TRIANGLE-LIST): one of
:point-list, :line-list, :line-strip, :triangle-list, :triangle-strip. Use
:line-list to draw wireframe/outline geometry — 2 vertices per drawn edge,
no index buffer required.

ENTRY-POINT (default \"main\") is the shared fallback for both shader stages.
VERTEX-ENTRY-POINT and FRAGMENT-ENTRY-POINT override the entry-point name for
each stage independently — use these when vertex and fragment stages have distinct
names (e.g. \"vs_main\" / \"fs_main\" as produced by the cl-webgpu/shader DSL).

VERTEX-BUFFER-LAYOUTS is an optional list of vertex buffer descriptors, each a
plist with:
  :array-stride  — byte stride across one vertex (required)
  :step-mode     — :vertex (default) or :instance
  :attributes    — list of attribute plists with :format, :offset, :shader-location

Example with two separate attribute buffers (position slot 0, colour slot 1):
  :vertex-buffer-layouts
  '((:array-stride 12 :step-mode :vertex
     :attributes ((:format :float32x3 :offset 0 :shader-location 0)))
    (:array-stride 16 :step-mode :vertex
     :attributes ((:format :float32x4 :offset 0 :shader-location 1))))

DEPTH-STENCIL-STATE is an optional plist enabling depth testing. Supported keys:
  :format               — depth texture format (default :depth24-plus)
  :depth-write-enabled  — write to depth buffer (default t)
  :depth-compare        — depth comparison function (default :less)
Stencil is disabled (stencil-write-mask 0, compare :always).

BLEND is an optional plist enabling alpha blending on the colour target. Supported keys:
  :color-src-factor     — (default :src-alpha)
  :color-dst-factor     — (default :one-minus-src-alpha)
  :color-operation      — (default :add)
  :alpha-src-factor     — (default :one)
  :alpha-dst-factor     — (default :one-minus-src-alpha)
  :alpha-operation      — (default :add)

Example:  :blend '() uses the defaults above (standard premultiplied alpha)

KNOWN BUG (weasel #84): :blend '() is NIL in Lisp, and the implementation
below branches on (if blend ...), so :blend '() is currently indistinguishable
from omitting :blend and actually leaves blending OFF -- the opposite of what
this docstring claims. Until fixed, pass the plist explicitly, e.g.
  :blend (list :color-src-factor :src-alpha :color-dst-factor :one-minus-src-alpha
               :color-operation :add :alpha-src-factor :one
               :alpha-dst-factor :one-minus-src-alpha :alpha-operation :add)"
  (let* ((vep      (or vertex-entry-point entry-point))
         (fep      (or fragment-entry-point entry-point))
         (desc         (foreign-alloc '(:struct wgpu-render-pipeline-descriptor)))
         (frag-state   (foreign-alloc '(:struct wgpu-fragment-state)))
         (color-target (foreign-alloc '(:struct wgpu-color-target-state)))
         (vep-data     (foreign-string-alloc vep))
         (vep-len      (length vep))
         (fep-data     (foreign-string-alloc fep))
         (fep-len      (length fep)))
    ;; Track extra allocations for vertex buffer layout foreign memory.
    (let ((extra-frees '()))
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
                (setf (foreign-slot-value ep '(:struct wgpu-string-view) 'data) vep-data
                      (foreign-slot-value ep '(:struct wgpu-string-view) 'length) vep-len))
              (setf (foreign-slot-value v '(:struct wgpu-vertex-state) 'constant-count) 0
                    (foreign-slot-value v '(:struct wgpu-vertex-state) 'constants) (null-pointer))
              (if vertex-buffer-layouts
                  (multiple-value-bind (lptr aptrs n)
                      (%build-vertex-buffer-layouts vertex-buffer-layouts)
                    ;; track for cleanup
                    (push lptr extra-frees)
                    (dolist (ap aptrs) (push ap extra-frees))
                    (setf (foreign-slot-value v '(:struct wgpu-vertex-state) 'buffer-count) n
                          (foreign-slot-value v '(:struct wgpu-vertex-state) 'buffers) lptr))
                  (setf (foreign-slot-value v '(:struct wgpu-vertex-state) 'buffer-count) 0
                        (foreign-slot-value v '(:struct wgpu-vertex-state) 'buffers) (null-pointer))))

          ;; primitive state
          (let ((p (foreign-slot-pointer desc '(:struct wgpu-render-pipeline-descriptor) 'primitive)))
            (setf (foreign-slot-value p '(:struct wgpu-primitive-state) 'next-in-chain) (null-pointer)
                  (foreign-slot-value p '(:struct wgpu-primitive-state) 'topology) topology
                  (foreign-slot-value p '(:struct wgpu-primitive-state) 'strip-index-format) :undefined
                  (foreign-slot-value p '(:struct wgpu-primitive-state) 'front-face) :ccw
                  (foreign-slot-value p '(:struct wgpu-primitive-state) 'cull-mode) :none
                  (foreign-slot-value p '(:struct wgpu-primitive-state) 'unclipped-depth) 0))

          ;; depth/stencil state (optional; nil disables depth testing)
          (if depth-stencil-state
              (let ((ds (foreign-alloc '(:struct wgpu-depth-stencil-state))))
                (push ds extra-frees)
                (setf (foreign-slot-value ds '(:struct wgpu-depth-stencil-state) 'next-in-chain) (null-pointer)
                      (foreign-slot-value ds '(:struct wgpu-depth-stencil-state) 'format)
                        (or (getf depth-stencil-state :format) :depth24-plus)
                      (foreign-slot-value ds '(:struct wgpu-depth-stencil-state) 'depth-write-enabled)
                        (if (getf depth-stencil-state :depth-write-enabled t) :true :false)
                      (foreign-slot-value ds '(:struct wgpu-depth-stencil-state) 'depth-compare)
                        (or (getf depth-stencil-state :depth-compare) :less)
                      (foreign-slot-value ds '(:struct wgpu-depth-stencil-state) 'stencil-read-mask) #xFFFFFFFF
                      (foreign-slot-value ds '(:struct wgpu-depth-stencil-state) 'stencil-write-mask) 0
                      (foreign-slot-value ds '(:struct wgpu-depth-stencil-state) 'depth-bias) 0
                      (foreign-slot-value ds '(:struct wgpu-depth-stencil-state) 'depth-bias-slope-scale) 0.0
                      (foreign-slot-value ds '(:struct wgpu-depth-stencil-state) 'depth-bias-clamp) 0.0)
                ;; stencil face states — no stencil (always/keep)
                (dolist (face-slot '(stencil-front stencil-back))
                  (let ((sf (foreign-slot-pointer ds '(:struct wgpu-depth-stencil-state) face-slot)))
                    (setf (foreign-slot-value sf '(:struct wgpu-stencil-face-state) 'compare)       :always
                          (foreign-slot-value sf '(:struct wgpu-stencil-face-state) 'fail-op)       :keep
                          (foreign-slot-value sf '(:struct wgpu-stencil-face-state) 'depth-fail-op) :keep
                          (foreign-slot-value sf '(:struct wgpu-stencil-face-state) 'pass-op)       :keep)))
                (setf (foreign-slot-value desc '(:struct wgpu-render-pipeline-descriptor) 'depth-stencil) ds))
              ;; no depth/stencil
              (setf (foreign-slot-value desc '(:struct wgpu-render-pipeline-descriptor) 'depth-stencil)
                    (null-pointer)))

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
                (foreign-slot-value color-target '(:struct wgpu-color-target-state) 'write-mask)
                #xF)
          (if blend
              (let ((bs (foreign-alloc '(:struct wgpu-blend-state))))
                (push bs extra-frees)
                (let ((color (foreign-slot-pointer bs '(:struct wgpu-blend-state) 'color))
                      (alpha (foreign-slot-pointer bs '(:struct wgpu-blend-state) 'alpha)))
                  (setf (foreign-slot-value color '(:struct wgpu-blend-component) 'src-factor)
                        (or (getf blend :color-src-factor) :src-alpha)
                        (foreign-slot-value color '(:struct wgpu-blend-component) 'dst-factor)
                        (or (getf blend :color-dst-factor) :one-minus-src-alpha)
                        (foreign-slot-value color '(:struct wgpu-blend-component) 'operation)
                        (or (getf blend :color-operation) :add)
                        (foreign-slot-value alpha '(:struct wgpu-blend-component) 'src-factor)
                        (or (getf blend :alpha-src-factor) :one)
                        (foreign-slot-value alpha '(:struct wgpu-blend-component) 'dst-factor)
                        (or (getf blend :alpha-dst-factor) :one-minus-src-alpha)
                        (foreign-slot-value alpha '(:struct wgpu-blend-component) 'operation)
                        (or (getf blend :alpha-operation) :add)))
                (setf (foreign-slot-value color-target '(:struct wgpu-color-target-state) 'blend) bs))
              (setf (foreign-slot-value color-target '(:struct wgpu-color-target-state) 'blend)
                    (null-pointer)))

          ;; fragment state
          (setf (foreign-slot-value frag-state '(:struct wgpu-fragment-state) 'next-in-chain)
                (null-pointer)
                (foreign-slot-value frag-state '(:struct wgpu-fragment-state) 'module)
                (handle fragment-module))
          (let ((ep (foreign-slot-pointer frag-state '(:struct wgpu-fragment-state) 'entry-point)))
            (setf (foreign-slot-value ep '(:struct wgpu-string-view) 'data) fep-data
                  (foreign-slot-value ep '(:struct wgpu-string-view) 'length) fep-len))
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
        ;; Free fixed allocations and any extra vertex-layout foreign memory.
        (foreign-free vep-data)
        (foreign-free fep-data)
        (foreign-free frag-state)
        (foreign-free color-target)
        (foreign-free desc)
        (dolist (p extra-frees)
          (unless (null-pointer-p p)
            (foreign-free p)))))))

(defun configure-surface (surface device format width height &key (present-mode 1))
  "Configure SURFACE for rendering. Call once after device creation.

   PRESENT-MODE is a raw WGPUPresentMode value (default 1, i.e. FIFO/vsync).
   Common values: 1 = Fifo (vsync on, guaranteed supported), 3 = Immediate
   (vsync off, tearing possible). Not every backend supports every mode --
   query WGPU-SURFACE-GET-CAPABILITIES if you need to verify support before
   configuring."
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
          (foreign-slot-value cfg '(:struct wgpu-surface-configuration) 'present-mode) present-mode)
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
                               (clear-b 0.0d0) (clear-a 1.0d0)
                               depth-view
                               (depth-clear-value 1.0))
  "Begin a render pass with a single colour attachment. Returns a GPU-RENDER-PASS.
The caller must call RELEASE on the returned pass or use WITH-RENDER-PASS.

When DEPTH-VIEW (a GPU-TEXTURE-VIEW for a depth texture) is supplied the pass
includes a depth-stencil attachment cleared to DEPTH-CLEAR-VALUE (default 1.0).
Stencil operations are left undefined (no stencil)."
  (let ((att      (foreign-alloc '(:struct wgpu-render-pass-color-attachment)))
        (desc     (foreign-alloc '(:struct wgpu-render-pass-descriptor)))
        (depth-att (when depth-view
                     (foreign-alloc '(:struct wgpu-render-pass-depth-stencil-attachment)))))
    (unwind-protect
        (progn
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
          ;; optional depth-stencil attachment
          (when depth-att
            (setf (foreign-slot-value depth-att '(:struct wgpu-render-pass-depth-stencil-attachment) 'next-in-chain) (null-pointer)
                  (foreign-slot-value depth-att '(:struct wgpu-render-pass-depth-stencil-attachment) 'view)
                  (etypecase depth-view
                    (gpu-texture-view (handle depth-view))
                    (t depth-view))
                  (foreign-slot-value depth-att '(:struct wgpu-render-pass-depth-stencil-attachment) 'depth-load-op) :clear
                  (foreign-slot-value depth-att '(:struct wgpu-render-pass-depth-stencil-attachment) 'depth-store-op) :store
                  (foreign-slot-value depth-att '(:struct wgpu-render-pass-depth-stencil-attachment) 'depth-clear-value) (float depth-clear-value 1.0)
                  (foreign-slot-value depth-att '(:struct wgpu-render-pass-depth-stencil-attachment) 'depth-read-only) 0
                  ;; stencil: leave undefined (no stencil in use)
                  (foreign-slot-value depth-att '(:struct wgpu-render-pass-depth-stencil-attachment) 'stencil-load-op) :undefined
                  (foreign-slot-value depth-att '(:struct wgpu-render-pass-depth-stencil-attachment) 'stencil-store-op) :undefined
                  (foreign-slot-value depth-att '(:struct wgpu-render-pass-depth-stencil-attachment) 'stencil-clear-value) 0
                  (foreign-slot-value depth-att '(:struct wgpu-render-pass-depth-stencil-attachment) 'stencil-read-only) 1))
          ;; pass descriptor
          (setf (foreign-slot-value desc '(:struct wgpu-render-pass-descriptor) 'next-in-chain) (null-pointer))
          (%set-string-view (foreign-slot-pointer desc '(:struct wgpu-render-pass-descriptor) 'label) nil)
          (setf (foreign-slot-value desc '(:struct wgpu-render-pass-descriptor) 'color-attachment-count) 1
                (foreign-slot-value desc '(:struct wgpu-render-pass-descriptor) 'color-attachments) att
                (foreign-slot-value desc '(:struct wgpu-render-pass-descriptor) 'depth-stencil-attachment)
                (if depth-att depth-att (null-pointer))
                (foreign-slot-value desc '(:struct wgpu-render-pass-descriptor) 'occlusion-query-set) (null-pointer)
                (foreign-slot-value desc '(:struct wgpu-render-pass-descriptor) 'timestamp-writes) (null-pointer))
          (make-instance 'gpu-render-pass
                         :handle (wgpu-command-encoder-begin-render-pass (handle encoder) desc)))
      (foreign-free desc)
      (foreign-free att)
      (when depth-att (foreign-free depth-att)))))

(defun submit-commands (encoder pass queue)
  "End PASS, finish ENCODER, and submit to QUEUE. Does not present.
Releases the command buffer; does not release ENCODER, PASS, or QUEUE.

Use this (instead of END-AND-SUBMIT) together with PRESENT-FRAME when the
render target may not be a real surface -- e.g. a headless GPU-OFFSCREEN-TARGET
from cl-webgpu/headless, where presenting means something other than
WGPU-SURFACE-PRESENT."
  (wgpu-render-pass-encoder-end (handle pass))
  (with-wgpu-struct (cmd-desc '(:struct wgpu-command-buffer-descriptor))
    (setf (foreign-slot-value cmd-desc '(:struct wgpu-command-buffer-descriptor) 'next-in-chain)
          (null-pointer))
    (%set-string-view (foreign-slot-pointer cmd-desc '(:struct wgpu-command-buffer-descriptor) 'label) nil)
    (let ((cmd-buf (wgpu-command-encoder-finish (handle encoder) cmd-desc)))
      (with-foreign-object (bufs 'wgpu-command-buffer 1)
        (setf (mem-aref bufs 'wgpu-command-buffer 0) cmd-buf)
        (wgpu-queue-submit (handle queue) 1 bufs))
      (wgpu-command-buffer-release cmd-buf))))

(defun end-and-submit (encoder pass queue surface)
  "End PASS, finish ENCODER, submit to QUEUE, and present SURFACE.
Releases the command buffer; does not release ENCODER, PASS, QUEUE, or SURFACE."
  (submit-commands encoder pass queue)
  (wgpu-surface-present (handle surface)))

;;;; -------------------------------------------------------------------------
;;;; Render-target seam
;;;;
;;;; ACQUIRE-FRAME-TEXTURE-VIEW / PRESENT-FRAME let render code stay agnostic
;;;; to whether it's drawing into a real on-screen surface or an offscreen
;;;; target (see cl-webgpu/headless). Write render loops against these two
;;;; generics plus SUBMIT-COMMANDS instead of calling WGPU-SURFACE-* directly,
;;;; and the same loop works headless for free.
;;;; -------------------------------------------------------------------------

(defgeneric acquire-frame-texture-view (target)
  (:documentation
   "Acquire a GPU-TEXTURE-VIEW for TARGET's current frame, or NIL if no frame
is available this call (e.g. a surface texture that came back suboptimal --
callers should skip rendering and try again next iteration). The caller is
responsible for RELEASE-ing the returned view once the frame's render pass
has been submitted."))

(defgeneric present-frame (target)
  (:documentation
   "Present/finalize the frame previously acquired from TARGET via
ACQUIRE-FRAME-TEXTURE-VIEW. For a real surface this presents to the screen;
offscreen targets may no-op here and expose readback separately."))

(defmethod acquire-frame-texture-view ((target gpu-surface))
  (with-wgpu-struct (st '(:struct wgpu-surface-texture))
    (wgpu-surface-get-current-texture (handle target) st)
    (let ((tex    (foreign-slot-value st '(:struct wgpu-surface-texture) 'texture))
          (status (mem-ref (foreign-slot-pointer st '(:struct wgpu-surface-texture) 'status) :uint32)))
      (when (and (not (null-pointer-p tex))
                 (or (= status 1) (= status 2))) ; success-optimal / success-suboptimal
        (with-wgpu-struct (vdesc '(:struct wgpu-texture-view-descriptor))
          (setf (foreign-slot-value vdesc '(:struct wgpu-texture-view-descriptor) 'mip-level-count) #xFFFFFFFF
                (foreign-slot-value vdesc '(:struct wgpu-texture-view-descriptor) 'array-layer-count) #xFFFFFFFF)
          (make-instance 'gpu-texture-view :handle (wgpu-texture-create-view tex vdesc)))))))

(defmethod present-frame ((target gpu-surface))
  (wgpu-surface-present (handle target)))

;;;; -------------------------------------------------------------------------
;;;; Buffer helpers
;;;; -------------------------------------------------------------------------

(defun make-buffer (device &key size (usage 0) (mapped-at-creation nil) label)
  "Create a WGPUBuffer. Returns a GPU-BUFFER.

USAGE is a bitwise-OR of +wgpu-buffer-usage-*+ constants.
MAPPED-AT-CREATION when T maps the buffer at creation for initial upload."
  (let ((desc (foreign-alloc '(:struct wgpu-buffer-descriptor)))
        label-data)
    (unwind-protect
        (progn
          (setf (foreign-slot-value desc '(:struct wgpu-buffer-descriptor) 'next-in-chain) (null-pointer))
          (setf label-data
                (%set-string-view (foreign-slot-pointer desc '(:struct wgpu-buffer-descriptor) 'label) label))
          (setf (foreign-slot-value desc '(:struct wgpu-buffer-descriptor) 'usage)   usage
                (foreign-slot-value desc '(:struct wgpu-buffer-descriptor) 'size)    size
                (foreign-slot-value desc '(:struct wgpu-buffer-descriptor) 'mapped-at-creation)
                (if mapped-at-creation 1 0))
          (let ((ptr (wgpu-device-create-buffer (handle device) desc)))
            (when (null-pointer-p ptr)
              (error "Failed to create buffer"))
            (make-instance 'gpu-buffer :handle ptr)))
      (when label-data (foreign-free label-data))
      (foreign-free desc))))

(defun write-buffer (queue buffer offset data size)
  "Upload SIZE bytes from foreign pointer DATA into BUFFER at byte OFFSET via QUEUE."
  (wgpu-queue-write-buffer (handle queue) (handle buffer) offset data size))


;;;; -------------------------------------------------------------------------
;;;; Texture helpers
;;;; -------------------------------------------------------------------------

(defun make-texture-2d (device width height
                        &key (format :rgba8-unorm)
                             (usage (logior +wgpu-texture-usage-texture-binding+
                                            +wgpu-texture-usage-copy-dst+))
                             label)
  "Create a 2D texture and a default view. Returns (values GPU-TEXTURE GPU-TEXTURE-VIEW).
Defaults to RGBA8 format with texture-binding + copy-dst usage for atlas uploads."
  (let* ((desc (foreign-alloc '(:struct wgpu-texture-descriptor)))
         label-data tex-ptr tex-view-ptr)
    (unwind-protect
        (progn
          (setf (foreign-slot-value desc '(:struct wgpu-texture-descriptor) 'next-in-chain) (null-pointer))
          (setf label-data
                (%set-string-view (foreign-slot-pointer desc '(:struct wgpu-texture-descriptor) 'label) label))
          (setf (foreign-slot-value desc '(:struct wgpu-texture-descriptor) 'usage)     usage
                (foreign-slot-value desc '(:struct wgpu-texture-descriptor) 'dimension) :2-d
                (foreign-slot-value desc '(:struct wgpu-texture-descriptor) 'format)    format
                (foreign-slot-value desc '(:struct wgpu-texture-descriptor) 'mip-level-count) 1
                (foreign-slot-value desc '(:struct wgpu-texture-descriptor) 'sample-count)    1
                (foreign-slot-value desc '(:struct wgpu-texture-descriptor) 'view-format-count) 0
                (foreign-slot-value desc '(:struct wgpu-texture-descriptor) 'view-formats) (null-pointer))
          (let ((sz (foreign-slot-pointer desc '(:struct wgpu-texture-descriptor) 'size)))
            (setf (foreign-slot-value sz '(:struct wgpu-extent3-d) 'width)  width
                  (foreign-slot-value sz '(:struct wgpu-extent3-d) 'height) height
                  (foreign-slot-value sz '(:struct wgpu-extent3-d) 'depth-or-array-layers) 1))
          (setf tex-ptr (wgpu-device-create-texture (handle device) desc))
          (when (null-pointer-p tex-ptr)
            (error "Failed to create texture"))
          (with-wgpu-struct (vd '(:struct wgpu-texture-view-descriptor))
            (setf (foreign-slot-value vd '(:struct wgpu-texture-view-descriptor) 'format)    format
                  (foreign-slot-value vd '(:struct wgpu-texture-view-descriptor) 'dimension) :2-d
                  (foreign-slot-value vd '(:struct wgpu-texture-view-descriptor) 'base-mip-level)    0
                  (foreign-slot-value vd '(:struct wgpu-texture-view-descriptor) 'mip-level-count)   #xFFFFFFFF
                  (foreign-slot-value vd '(:struct wgpu-texture-view-descriptor) 'base-array-layer)  0
                  (foreign-slot-value vd '(:struct wgpu-texture-view-descriptor) 'array-layer-count) #xFFFFFFFF
                  (foreign-slot-value vd '(:struct wgpu-texture-view-descriptor) 'aspect) :all)
            (setf tex-view-ptr (wgpu-texture-create-view tex-ptr vd)))
          (values (make-instance 'gpu-texture      :handle tex-ptr)
                  (make-instance 'gpu-texture-view :handle tex-view-ptr)))
      (when label-data (foreign-free label-data))
      (foreign-free desc))))

(defun write-texture (queue texture-view data data-size &key width height (bytes-per-row 0))
  "Upload DATA (foreign pointer, DATA-SIZE bytes) to TEXTURE-VIEW as a full 2D image.
BYTES-PER-ROW must be set to width * bytes-per-texel."
  (with-foreign-object (dst '(:struct wgpu-texel-copy-texture-info))
    (foreign-funcall "memset" :pointer dst :int 0
                    :size (foreign-type-size '(:struct wgpu-texel-copy-texture-info)) :void)
    (setf (foreign-slot-value dst '(:struct wgpu-texel-copy-texture-info) 'texture)
          (etypecase texture-view
            (gpu-texture      (handle texture-view))
            (gpu-texture-view (handle texture-view))
            (t texture-view))
          (foreign-slot-value dst '(:struct wgpu-texel-copy-texture-info) 'mip-level) 0
          (foreign-slot-value dst '(:struct wgpu-texel-copy-texture-info) 'aspect) :all)
    (with-foreign-object (layout '(:struct wgpu-texel-copy-buffer-layout))
      (setf (foreign-slot-value layout '(:struct wgpu-texel-copy-buffer-layout) 'offset) 0
            (foreign-slot-value layout '(:struct wgpu-texel-copy-buffer-layout) 'bytes-per-row) bytes-per-row
            (foreign-slot-value layout '(:struct wgpu-texel-copy-buffer-layout) 'rows-per-image) height)
      (with-foreign-object (sz '(:struct wgpu-extent3-d))
        (setf (foreign-slot-value sz '(:struct wgpu-extent3-d) 'width)  width
              (foreign-slot-value sz '(:struct wgpu-extent3-d) 'height) height
              (foreign-slot-value sz '(:struct wgpu-extent3-d) 'depth-or-array-layers) 1)
        (wgpu-queue-write-texture (handle queue) dst data data-size layout sz)))))


;;;; -------------------------------------------------------------------------
;;;; Sampler helper
;;;; -------------------------------------------------------------------------

(defun make-sampler (device &key (mag-filter :linear) (min-filter :linear)
                                 (address-mode :clamp-to-edge))
  "Create a WGPUSampler. Returns a raw WGPUSampler handle (not a CLOS wrapper).
ADDRESS-MODE applies to all three axes."
  (with-wgpu-struct (desc '(:struct wgpu-sampler-descriptor))
    (setf (foreign-slot-value desc '(:struct wgpu-sampler-descriptor) 'next-in-chain) (null-pointer)
          (foreign-slot-value desc '(:struct wgpu-sampler-descriptor) 'address-mode-u) address-mode
          (foreign-slot-value desc '(:struct wgpu-sampler-descriptor) 'address-mode-v) address-mode
          (foreign-slot-value desc '(:struct wgpu-sampler-descriptor) 'address-mode-w) address-mode
          (foreign-slot-value desc '(:struct wgpu-sampler-descriptor) 'mag-filter) mag-filter
          (foreign-slot-value desc '(:struct wgpu-sampler-descriptor) 'min-filter)  min-filter
          (foreign-slot-value desc '(:struct wgpu-sampler-descriptor) 'mipmap-filter) :nearest
          (foreign-slot-value desc '(:struct wgpu-sampler-descriptor) 'lod-min-clamp) 0.0
          (foreign-slot-value desc '(:struct wgpu-sampler-descriptor) 'lod-max-clamp) 32.0
          (foreign-slot-value desc '(:struct wgpu-sampler-descriptor) 'compare) :undefined
          (foreign-slot-value desc '(:struct wgpu-sampler-descriptor) 'max-anisotropy) 1)
    (%set-string-view (foreign-slot-pointer desc '(:struct wgpu-sampler-descriptor) 'label) nil)
    (let ((ptr (wgpu-device-create-sampler (handle device) desc)))
      (when (null-pointer-p ptr)
        (error "Failed to create sampler"))
      ptr)))


;;;; -------------------------------------------------------------------------
;;;; Bind-group helpers
;;;; -------------------------------------------------------------------------

(defun get-pipeline-bind-group-layout (pipeline group-index)
  "Return the WGPUBindGroupLayout for GROUP-INDEX of PIPELINE (auto-layout mode)."
  (wgpu-render-pipeline-get-bind-group-layout (handle pipeline) group-index))

(defun make-bind-group (device layout entries)
  "Create a WGPUBindGroup. Returns a raw WGPUBindGroup handle.

LAYOUT is a raw WGPUBindGroupLayout handle.
ENTRIES is a list of plists, each with:
  :binding      — binding index (required)
  :buffer       — a GPU-BUFFER or raw buffer handle (exclusive with :sampler/:texture-view)
  :offset       — byte offset into buffer (default 0)
  :size         — byte size for buffer binding (default 0 = whole buffer)
  :sampler      — a raw WGPUSampler handle
  :texture-view — a GPU-TEXTURE-VIEW or raw texture view handle"
  (let* ((n     (length entries))
         (eptr  (if (plusp n)
                    (foreign-alloc '(:struct wgpu-bind-group-entry) :count n)
                    (null-pointer))))
    (unwind-protect
        (progn
          (loop for e in entries for i from 0 do
                (let ((ep (mem-aptr eptr '(:struct wgpu-bind-group-entry) i)))
                  (foreign-funcall "memset" :pointer ep :int 0
                                  :size (foreign-type-size '(:struct wgpu-bind-group-entry)) :void)
                  (setf (foreign-slot-value ep '(:struct wgpu-bind-group-entry) 'next-in-chain) (null-pointer)
                        (foreign-slot-value ep '(:struct wgpu-bind-group-entry) 'binding)
                        (getf e :binding 0))
                  (let ((buf (getf e :buffer))
                        (smp (getf e :sampler))
                        (tv  (getf e :texture-view)))
                    (cond
                      (buf
                       (setf (foreign-slot-value ep '(:struct wgpu-bind-group-entry) 'buffer)
                             (etypecase buf (gpu-buffer (handle buf)) (t buf))
                             (foreign-slot-value ep '(:struct wgpu-bind-group-entry) 'offset)
                             (getf e :offset 0)
                             (foreign-slot-value ep '(:struct wgpu-bind-group-entry) 'size)
                             (getf e :size 0)))
                      (smp
                       (setf (foreign-slot-value ep '(:struct wgpu-bind-group-entry) 'sampler) smp))
                      (tv
                       (setf (foreign-slot-value ep '(:struct wgpu-bind-group-entry) 'texture-view)
                             (etypecase tv
                               (gpu-texture-view (handle tv))
                               (t tv))))))))
          (with-wgpu-struct (desc '(:struct wgpu-bind-group-descriptor))
            (setf (foreign-slot-value desc '(:struct wgpu-bind-group-descriptor) 'next-in-chain) (null-pointer)
                  (foreign-slot-value desc '(:struct wgpu-bind-group-descriptor) 'layout) layout
                  (foreign-slot-value desc '(:struct wgpu-bind-group-descriptor) 'entry-count) n
                  (foreign-slot-value desc '(:struct wgpu-bind-group-descriptor) 'entries)
                  (if (plusp n) eptr (null-pointer)))
            (%set-string-view (foreign-slot-pointer desc '(:struct wgpu-bind-group-descriptor) 'label) nil)
            (let ((ptr (wgpu-device-create-bind-group (handle device) desc)))
              (when (null-pointer-p ptr)
                (error "Failed to create bind group"))
              ptr)))
      (unless (null-pointer-p eptr)
        (foreign-free eptr)))))


;;;; -------------------------------------------------------------------------
;;;; Render-pass draw helpers (thin wrappers over FFI calls)
;;;; -------------------------------------------------------------------------

(defun set-vertex-buffer (pass slot buffer &key (offset 0) size)
  "Bind BUFFER to vertex slot SLOT on PASS. SIZE defaults to the whole buffer."
  (wgpu-render-pass-encoder-set-vertex-buffer
   (handle pass) slot (handle buffer) offset (or size #xFFFFFFFFFFFFFFFF)))

(defun set-index-buffer (pass buffer &key (format :uint16) (offset 0) size)
  "Bind BUFFER as the index buffer on PASS."
  (wgpu-render-pass-encoder-set-index-buffer
   (handle pass) (handle buffer) format offset (or size #xFFFFFFFFFFFFFFFF)))

(defun set-bind-group (pass group-index bind-group)
  "Bind BIND-GROUP at GROUP-INDEX on PASS. BIND-GROUP is a raw WGPUBindGroup handle."
  (wgpu-render-pass-encoder-set-bind-group (handle pass) group-index bind-group 0 (null-pointer)))

(defun set-scissor-rect (pass x y width height)
  "Set the scissor rect on PASS. All values are integers in pixels."
  (wgpu-render-pass-encoder-set-scissor-rect (handle pass) x y width height))

(defun set-viewport (pass x y width height &key (min-depth 0.0) (max-depth 1.0))
  "Set the viewport on PASS. X/Y/WIDTH/HEIGHT are floats in pixels -- unlike
SET-SCISSOR-RECT, the viewport also rescales clip-space, so it (not scissor)
is what's needed to letterbox a non-square render target."
  (wgpu-render-pass-encoder-set-viewport
   (handle pass) (float x 1.0) (float y 1.0) (float width 1.0) (float height 1.0)
   (float min-depth 1.0) (float max-depth 1.0)))

(defun draw-indexed (pass index-count &key (instance-count 1) (first-index 0) (base-vertex 0))
  "Issue an indexed draw call on PASS."
  (wgpu-render-pass-encoder-draw-indexed
   (handle pass) index-count instance-count first-index base-vertex 0))

(defun draw (pass vertex-count &key (instance-count 1) (first-vertex 0) (first-instance 0))
  "Issue a non-indexed draw call on PASS -- e.g. for :LINE-LIST topology
(see MAKE-RENDER-PIPELINE's :TOPOLOGY), which doesn't need an index buffer."
  (wgpu-render-pass-encoder-draw
   (handle pass) vertex-count instance-count first-vertex first-instance))

(defun set-pipeline (pass pipeline)
  "Bind PIPELINE (a GPU-RENDER-PIPELINE) as PASS's active render pipeline."
  (wgpu-render-pass-encoder-set-pipeline (handle pass) (handle pipeline)))


(defun make-depth-texture (device width height &key (format :depth24-plus))
  "Create a depth texture and a depth-only view of the given dimensions.
Returns two values: (GPU-TEXTURE GPU-TEXTURE-VIEW).
The caller is responsible for releasing both (RELEASE texture then RELEASE view).

FORMAT defaults to :DEPTH24-PLUS. Pass the view to BEGIN-RENDER-PASS as :DEPTH-VIEW
and use the same FORMAT keyword for the pipeline's :DEPTH-STENCIL-STATE.

NOTE: The #xFFFFFFFF sentinel for mip-level-count and array-layer-count instructs
WebGPU to use the full mip/layer range of the texture."
  (let* ((tex-desc (foreign-alloc '(:struct wgpu-texture-descriptor)))
         tex-ptr tex-view-ptr)
    (unwind-protect
        (progn
          (setf (foreign-slot-value tex-desc '(:struct wgpu-texture-descriptor) 'next-in-chain) (null-pointer))
          (%set-string-view (foreign-slot-pointer tex-desc '(:struct wgpu-texture-descriptor) 'label) nil)
          (setf (foreign-slot-value tex-desc '(:struct wgpu-texture-descriptor) 'usage)
                +wgpu-texture-usage-render-attachment+
                (foreign-slot-value tex-desc '(:struct wgpu-texture-descriptor) 'dimension) :2-d
                (foreign-slot-value tex-desc '(:struct wgpu-texture-descriptor) 'format) format
                (foreign-slot-value tex-desc '(:struct wgpu-texture-descriptor) 'mip-level-count) 1
                (foreign-slot-value tex-desc '(:struct wgpu-texture-descriptor) 'sample-count) 1
                (foreign-slot-value tex-desc '(:struct wgpu-texture-descriptor) 'view-format-count) 0
                (foreign-slot-value tex-desc '(:struct wgpu-texture-descriptor) 'view-formats) (null-pointer))
          (let ((sz (foreign-slot-pointer tex-desc '(:struct wgpu-texture-descriptor) 'size)))
            (setf (foreign-slot-value sz '(:struct wgpu-extent3-d) 'width)  width
                  (foreign-slot-value sz '(:struct wgpu-extent3-d) 'height) height
                  (foreign-slot-value sz '(:struct wgpu-extent3-d) 'depth-or-array-layers) 1))
          (setf tex-ptr (wgpu-device-create-texture (handle device) tex-desc))
          ;; Create a depth-only view
          (with-wgpu-struct (vd '(:struct wgpu-texture-view-descriptor))
            (setf (foreign-slot-value vd '(:struct wgpu-texture-view-descriptor) 'format) format
                  (foreign-slot-value vd '(:struct wgpu-texture-view-descriptor) 'dimension) :2-d
                  (foreign-slot-value vd '(:struct wgpu-texture-view-descriptor) 'base-mip-level) 0
                  (foreign-slot-value vd '(:struct wgpu-texture-view-descriptor) 'mip-level-count) #xFFFFFFFF
                  (foreign-slot-value vd '(:struct wgpu-texture-view-descriptor) 'base-array-layer) 0
                  (foreign-slot-value vd '(:struct wgpu-texture-view-descriptor) 'array-layer-count) #xFFFFFFFF
                  (foreign-slot-value vd '(:struct wgpu-texture-view-descriptor) 'aspect) :depth-only)
            (setf tex-view-ptr (wgpu-texture-create-view tex-ptr vd)))
          (values (make-instance 'gpu-texture      :handle tex-ptr)
                  (make-instance 'gpu-texture-view :handle tex-view-ptr)))
      (foreign-free tex-desc))))
