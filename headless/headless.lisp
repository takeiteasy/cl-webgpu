;;;; headless/headless.lisp
;;;;
;;;; Offscreen render target + PNG readback for headless testing (no window,
;;;; no display server, no screen-recording permissions needed -- rendering
;;;; happens entirely on the GPU and the result is read back over the wire).
;;;;
;;;; Pair with cl-webgpu/glfw-dummy to run an app's existing GLFW-driven main
;;;; loop headless: swap the real GLFW package for the dummy and a real
;;;; GPU-SURFACE for a GPU-OFFSCREEN-TARGET, and any render loop written
;;;; against ACQUIRE-FRAME-TEXTURE-VIEW / PRESENT-FRAME (see cl-webgpu/wrapper)
;;;; keeps working unmodified.

(in-package #:cl-webgpu/headless)

(defclass gpu-offscreen-target (gpu-handle)
  ((texture :initarg :texture :accessor offscreen-target-texture)
   (width   :initarg :width   :accessor offscreen-target-width)
   (height  :initarg :height  :accessor offscreen-target-height)
   (format  :initarg :format  :accessor offscreen-target-format)))

(defmethod release ((obj gpu-offscreen-target))
  (release (offscreen-target-texture obj)))

(defun make-offscreen-target (device width height &key (format :rgba8-unorm))
  "Create a GPU-OFFSCREEN-TARGET: a persistent WIDTHxHEIGHT texture render
target with RENDER_ATTACHMENT + COPY_SRC usage, suitable for
ACQUIRE-FRAME-TEXTURE-VIEW/PRESENT-FRAME and later READBACK-TEXTURE-PNG."
  (let ((tex (make-texture-2d device width height
                              :format format
                              :usage (logior +wgpu-texture-usage-render-attachment+
                                             +wgpu-texture-usage-copy-src+))))
    (make-instance 'gpu-offscreen-target
                   :handle (handle tex) :texture tex
                   :width width :height height :format format)))

(defmethod acquire-frame-texture-view ((target gpu-offscreen-target))
  (with-wgpu-struct (vdesc '(:struct wgpu-texture-view-descriptor))
    (setf (foreign-slot-value vdesc '(:struct wgpu-texture-view-descriptor) 'mip-level-count) #xFFFFFFFF
          (foreign-slot-value vdesc '(:struct wgpu-texture-view-descriptor) 'array-layer-count) #xFFFFFFFF)
    (make-instance 'gpu-texture-view
                   :handle (wgpu-texture-create-view (handle (offscreen-target-texture target)) vdesc))))

(defmethod present-frame ((target gpu-offscreen-target))
  "No-op: an offscreen target has nothing to present to. Read its contents
back explicitly with READBACK-TEXTURE-PNG once rendering is done."
  (declare (ignore target))
  nil)

;;;; -------------------------------------------------------------------------
;;;; Readback: texture -> buffer -> PNG
;;;; -------------------------------------------------------------------------

(defvar *%map-done* nil
  "Set by %BUFFER-MAP-CALLBACK once WGPU-BUFFER-MAP-ASYNC's callback fires.
Readback is synchronous/single-threaded (one readback in flight at a time),
so a single dynamic flag is sufficient.")

(defcallback %buffer-map-callback :void
    ((status wgpu-map-async-status) (message-data :pointer) (message-length :size)
     (userdata1 :pointer) (userdata2 :pointer))
  (declare (ignore message-data message-length userdata1 userdata2))
  (setf *%map-done* (if (eq status :success) :success status)))

(defun %map-buffer-read-sync (device buffer size)
  "Map BUFFER (SIZE bytes) for reading and block until the map completes.
Signals an error if the map does not succeed."
  (let ((*%map-done* nil))
    (with-wgpu-struct (out-future '(:struct wgpu-future))
      (wgpu-buffer-map-async (handle buffer) +wgpu-buffer-usage-map-read+ 0 size
                             (null-pointer) :allow-process-events
                             (callback %buffer-map-callback)
                             (null-pointer) (null-pointer)
                             out-future))
    (loop until *%map-done*
          do (wgpu-device-poll (handle device) 1 (null-pointer)))
    (unless (eq *%map-done* :success)
      (error "wgpu buffer map failed: ~a" *%map-done*))))

(defconstant +copy-row-alignment+ 256
  "wgpu requires COPY_TEXTURE_TO_BUFFER's bytesPerRow to be a multiple of this.")

(defun %aligned-bytes-per-row (width bytes-per-pixel)
  (let ((unaligned (* width bytes-per-pixel)))
    (* +copy-row-alignment+ (ceiling unaligned +copy-row-alignment+))))

(defun readback-texture-png (device queue target path)
  "Read the current contents of TARGET (a GPU-OFFSCREEN-TARGET, RGBA8 format)
back from the GPU and write them to PATH as a PNG. Blocks until the readback
completes."
  (unless (eq (offscreen-target-format target) :rgba8-unorm)
    (error "READBACK-TEXTURE-PNG only supports :RGBA8-UNORM targets, got ~a"
           (offscreen-target-format target)))
  (let* ((width  (offscreen-target-width target))
         (height (offscreen-target-height target))
         (bytes-per-pixel 4)
         (padded-bytes-per-row (%aligned-bytes-per-row width bytes-per-pixel))
         (buffer-size (* padded-bytes-per-row height))
         (buffer (make-buffer device :size buffer-size
                              :usage (logior +wgpu-buffer-usage-map-read+
                                             +wgpu-buffer-usage-copy-dst+))))
    (unwind-protect
        (progn
          (let ((encoder (make-command-encoder device)))
            (unwind-protect
                (with-wgpu-struct (src '(:struct wgpu-texel-copy-texture-info))
                  (setf (foreign-slot-value src '(:struct wgpu-texel-copy-texture-info) 'texture)
                        (handle (offscreen-target-texture target))
                        (foreign-slot-value src '(:struct wgpu-texel-copy-texture-info) 'mip-level) 0
                        (foreign-slot-value src '(:struct wgpu-texel-copy-texture-info) 'aspect) :all)
                  (let ((org (foreign-slot-pointer src '(:struct wgpu-texel-copy-texture-info) 'origin)))
                    (setf (foreign-slot-value org '(:struct wgpu-origin3-d) 'x) 0
                          (foreign-slot-value org '(:struct wgpu-origin3-d) 'y) 0
                          (foreign-slot-value org '(:struct wgpu-origin3-d) 'z) 0))
                  (with-wgpu-struct (dst '(:struct wgpu-texel-copy-buffer-info))
                    (setf (foreign-slot-value dst '(:struct wgpu-texel-copy-buffer-info) 'buffer) (handle buffer))
                    (let ((layout (foreign-slot-pointer dst '(:struct wgpu-texel-copy-buffer-info) 'layout)))
                      (setf (foreign-slot-value layout '(:struct wgpu-texel-copy-buffer-layout) 'offset) 0
                            (foreign-slot-value layout '(:struct wgpu-texel-copy-buffer-layout) 'bytes-per-row) padded-bytes-per-row
                            (foreign-slot-value layout '(:struct wgpu-texel-copy-buffer-layout) 'rows-per-image) height))
                    (with-wgpu-struct (extent '(:struct wgpu-extent3-d))
                      (setf (foreign-slot-value extent '(:struct wgpu-extent3-d) 'width) width
                            (foreign-slot-value extent '(:struct wgpu-extent3-d) 'height) height
                            (foreign-slot-value extent '(:struct wgpu-extent3-d) 'depth-or-array-layers) 1)
                      (wgpu-command-encoder-copy-texture-to-buffer (handle encoder) src dst extent)))
                  (with-wgpu-struct (cmd-desc '(:struct wgpu-command-buffer-descriptor))
                    (setf (foreign-slot-value cmd-desc '(:struct wgpu-command-buffer-descriptor) 'next-in-chain)
                          (null-pointer))
                    (let ((cmd-buf (wgpu-command-encoder-finish (handle encoder) cmd-desc)))
                      (with-foreign-object (bufs 'wgpu-command-buffer 1)
                        (setf (mem-aref bufs 'wgpu-command-buffer 0) cmd-buf)
                        (wgpu-queue-submit (handle queue) 1 bufs))
                      (wgpu-command-buffer-release cmd-buf))))
              (release encoder)))
          (%map-buffer-read-sync device buffer buffer-size)
          (let ((raw (wgpu-buffer-get-mapped-range (handle buffer) 0 buffer-size)))
            (when (null-pointer-p raw)
              (error "wgpuBufferGetMappedRange returned NULL"))
            (let ((png (make-instance 'zpng:png :width width :height height
                                      :color-type :truecolor-alpha)))
              (let ((image (zpng:data-array png)))
                (dotimes (row height)
                  (let ((row-offset (* row padded-bytes-per-row)))
                    (dotimes (col width)
                      (let ((px (+ row-offset (* col bytes-per-pixel))))
                        (setf (aref image row col 0) (mem-aref raw :uint8 px)
                              (aref image row col 1) (mem-aref raw :uint8 (+ px 1))
                              (aref image row col 2) (mem-aref raw :uint8 (+ px 2))
                              (aref image row col 3) (mem-aref raw :uint8 (+ px 3))))))))
              (zpng:write-png png path)))
          (wgpu-buffer-unmap (handle buffer)))
      (release buffer))
    path))
