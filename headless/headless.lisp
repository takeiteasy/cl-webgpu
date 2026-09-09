;;;; headless/headless.lisp
;;;;
;;;; Render into an offscreen GPU target and read the result back as a PNG --
;;;; no window, no display server, no screen-recording permission (rendering
;;;; happens entirely on the GPU and the result is read back over the wire).
;;;; Useful for testing graphics changes over SSH/CI, where there's no screen
;;;; to look at and screenshotting is unreliable.
;;;;
;;;; A HEADLESS-TARGET implements cl-webgpu/wrapper's render-target seam
;;;; (ACQUIRE-FRAME-TEXTURE-VIEW / PRESENT-FRAME), so render loops written
;;;; against that seam (see cl-webgpu/wrapper) accept a HEADLESS-TARGET
;;;; wherever they accept a GPU-SURFACE. Any windowing backend's surface
;;;; (GLFW today, SDL3 tomorrow) plugs into the same seam.

(in-package #:cl-webgpu/headless)

(defclass headless-target (gpu-handle)
  ((texture :initarg :texture :accessor headless-target-texture)
   (width   :initarg :width   :accessor headless-target-width)
   (height  :initarg :height  :accessor headless-target-height)
   (format  :initarg :format  :accessor headless-target-format)))

(defmethod release ((obj headless-target))
  (release (headless-target-texture obj)))

(defun make-headless-target (device width height &key (format :rgba8-unorm))
  "Create a HEADLESS-TARGET: a persistent WIDTHxHEIGHT texture render target
with RENDER_ATTACHMENT + COPY_SRC usage, suitable for
ACQUIRE-FRAME-TEXTURE-VIEW/PRESENT-FRAME and later READBACK-TEXTURE-PNG."
  (let ((tex (make-texture-2d device width height
                              :format format
                              :usage (logior +wgpu-texture-usage-render-attachment+
                                             +wgpu-texture-usage-copy-src+))))
    (make-instance 'headless-target
                   :handle (handle tex) :texture tex
                   :width width :height height :format format)))

(defmethod acquire-frame-texture-view ((target headless-target))
  "Return a fresh GPU-TEXTURE-VIEW covering TARGET's whole texture. There is
no swapchain here, so a view is always available; release it once the frame's
render pass has been submitted (WITH-HEADLESS-FRAME does this for you)."
  (with-wgpu-struct (vdesc '(:struct wgpu-texture-view-descriptor))
    (setf (foreign-slot-value vdesc '(:struct wgpu-texture-view-descriptor) 'mip-level-count) #xFFFFFFFF
          (foreign-slot-value vdesc '(:struct wgpu-texture-view-descriptor) 'array-layer-count) #xFFFFFFFF)
    (make-instance 'gpu-texture-view
                   :handle (wgpu-texture-create-view (handle (headless-target-texture target)) vdesc))))

(defmethod present-frame ((target headless-target))
  "No-op: a headless target has nothing to present to. Read its contents
back explicitly with READBACK-TEXTURE-PNG once rendering is done."
  (declare (ignore target))
  nil)

;;;; -------------------------------------------------------------------------
;;;; One-frame convenience
;;;; -------------------------------------------------------------------------

(defmacro with-headless-frame ((pass device queue target &rest render-pass-options) &body body)
  "Render one frame into TARGET: acquire its texture view, open a render pass
on it bound to PASS (RENDER-PASS-OPTIONS go to BEGIN-RENDER-PASS, e.g.
:clear-r), run BODY (draw calls only -- the macro ends the pass and submits),
then release the view and present.

BODY must not call SUBMIT-COMMANDS itself; the macro submits exactly once
after BODY returns. For multiple render passes per frame, drop to
ACQUIRE-FRAME-TEXTURE-VIEW / WITH-RENDER-PASS / SUBMIT-COMMANDS /
PRESENT-FRAME by hand. Works over any render target implementing the seam
(a real GPU-SURFACE too), not just a HEADLESS-TARGET.

The expansion references cl-webgpu/wrapper's symbols fully qualified, so it
expands correctly in packages that don't USE cl-webgpu/wrapper."
  (let ((view (gensym "VIEW"))
        (encoder (gensym "ENCODER")))
    `(let ((,view (cl-webgpu/wrapper:acquire-frame-texture-view ,target)))
       (unwind-protect
           (cl-webgpu/wrapper:with-gpu-command-encoder (,encoder ,device)
             (cl-webgpu/wrapper:with-render-pass (,pass ,encoder ,view ,@render-pass-options)
               ,@body
               (cl-webgpu/wrapper:submit-commands ,encoder ,pass ,queue)))
         (cl-webgpu/wrapper:release ,view))
       (cl-webgpu/wrapper:present-frame ,target))))

;;;; -------------------------------------------------------------------------
;;;; Readback: texture -> buffer -> pixels -> PNG
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

(defun %copy-target-to-buffer (device queue target buffer padded-bytes-per-row)
  "Encode and submit a COPY_TEXTURE_TO_BUFFER of TARGET into BUFFER (whose
rows are PADDED-BYTES-PER-ROW apart). Internal: caller owns DEVICE, QUEUE,
BUFFER, and releases the buffer."
  (let ((encoder (make-command-encoder device)))
    (unwind-protect
        (with-wgpu-struct (src '(:struct wgpu-texel-copy-texture-info))
          (setf (foreign-slot-value src '(:struct wgpu-texel-copy-texture-info) 'texture)
                (handle (headless-target-texture target))
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
                    (foreign-slot-value layout '(:struct wgpu-texel-copy-buffer-layout) 'rows-per-image)
                    (headless-target-height target)))
            (with-wgpu-struct (extent '(:struct wgpu-extent3-d))
              (setf (foreign-slot-value extent '(:struct wgpu-extent3-d) 'width)
                    (headless-target-width target)
                    (foreign-slot-value extent '(:struct wgpu-extent3-d) 'height)
                    (headless-target-height target)
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
      (release encoder))))

(defun readback-texture-data (device queue target)
  "Read the current contents of TARGET (a HEADLESS-TARGET, :RGBA8-UNORM)
back from the GPU as a flat (SIMPLE-ARRAY (UNSIGNED-BYTE 8) (*)) of
WIDTH*HEIGHT*4 tightly packed RGBA8 bytes. Blocks until the readback
completes. (wgpu's 256-byte row-alignment requirement is handled
internally; rows are unpadded here.)"
  (unless (eq (headless-target-format target) :rgba8-unorm)
    (error "Readback only supports :RGBA8-UNORM targets, got ~a"
           (headless-target-format target)))
  (let* ((width  (headless-target-width target))
         (height (headless-target-height target))
         (bytes-per-pixel 4)
         (padded-bytes-per-row (%aligned-bytes-per-row width bytes-per-pixel))
         (buffer-size (* padded-bytes-per-row height))
         (buffer (make-buffer device :size buffer-size
                              :usage (logior +wgpu-buffer-usage-map-read+
                                             +wgpu-buffer-usage-copy-dst+))))
    (unwind-protect
        (let ((raw (progn
                     (%copy-target-to-buffer device queue target buffer padded-bytes-per-row)
                     (%map-buffer-read-sync device buffer buffer-size)
                     (wgpu-buffer-get-mapped-range (handle buffer) 0 buffer-size))))
          (when (null-pointer-p raw)
            (error "wgpuBufferGetMappedRange returned NULL"))
          (let ((data (make-array (* width height bytes-per-pixel)
                                  :element-type '(unsigned-byte 8))))
            (dotimes (row height)
              (let ((row-offset (* row padded-bytes-per-row)))
                (dotimes (col width)
                  (let ((px (+ row-offset (* col bytes-per-pixel)))
                        (out (+ (* row width bytes-per-pixel)
                                (* col bytes-per-pixel))))
                    (setf (aref data (+ out 0)) (mem-aref raw :uint8 px)
                          (aref data (+ out 1)) (mem-aref raw :uint8 (+ px 1))
                          (aref data (+ out 2)) (mem-aref raw :uint8 (+ px 2))
                          (aref data (+ out 3)) (mem-aref raw :uint8 (+ px 3)))))))
            (wgpu-buffer-unmap (handle buffer))
            data))
      (release buffer))))

(defun readback-texture-png (device queue target path)
  "Read the current contents of TARGET (a HEADLESS-TARGET, :RGBA8-UNORM)
back from the GPU and write them to PATH as a PNG. Blocks until the readback
completes."
  (let ((png (make-instance 'zpng:png
                            :width (headless-target-width target)
                            :height (headless-target-height target)
                            :color-type :truecolor-alpha
                            :image-data (readback-texture-data device queue target))))
    (zpng:write-png png path))
  path)
