(defpackage #:cl-webgpu/imgui-input-common
  (:use #:cl)
  (:local-nicknames (#:ig #:cl-dear-imgui))
  (:export #:*debug-input*
           #:pump-imgui-frame
           #:reset-clock))

(in-package #:cl-webgpu/imgui-input-common)

;;;; ---------------------------------------------------------------------------
;;;; Shared Dear ImGui input plumbing for the per-windowing-backend glue systems
;;;; (cl-webgpu/imgui-glfw-glue, cl-webgpu/imgui-sdl3-glue).
;;;;
;;;; Unlike the Nuklear glue, ImGui takes *pushed* events: scroll and typed text
;;;; are handed straight to ImGuiIO from the backend's C callback / event watch
;;;; (io-add-mouse-wheel-event, io-add-input-character) -- ImGui queues them and
;;;; de-duplicates, so there is no accumulate-then-drain step here. What is
;;;; genuinely shared is the per-frame bookkeeping PUMP-IMGUI-FRAME does:
;;;; DisplaySize (logical points), DisplayFramebufferScale (pixels per point),
;;;; a monotonic DeltaTime, and polling the cursor / buttons / keys.
;;;;
;;;; The clock is process-global, so only one window's timing can be tracked at
;;;; a time -- fine for this codebase's single-window apps, same caveat as the
;;;; Nuklear glue. A genuinely multi-window / multi-threaded host would need
;;;; per-context state and a lock.
;;;; ---------------------------------------------------------------------------

(defvar *debug-input* nil
  "When non-nil, PUMP-IMGUI-FRAME prints per-frame size/scale diagnostics.")

(defvar *last-time* nil
  "internal-real-time of the previous PUMP-IMGUI-FRAME, for DeltaTime.")

(defun reset-clock ()
  "Drop the stored timestamp so the next frame's DeltaTime is a nominal 1/60 s.
Call when installing input callbacks or resuming after a pause."
  (setf *last-time* nil))

(defun %tick ()
  "Seconds since the previous call; a positive nominal value on the first call."
  (let ((now (get-internal-real-time)))
    (prog1
        (if *last-time*
            (max 1f-4 (/ (float (- now *last-time*) 1f0)
                         internal-time-units-per-second))
            (/ 1f0 60f0))
      (setf *last-time* now))))

(defun pump-imgui-frame (&key pixel-size point-size cursor-position
                              tracked-buttons button-pressed-p
                              tracked-keys key-pressed-p)
  "Feed one frame of backend state into the current ImGui context's IO, then
leave IG:NEW-FRAME to the caller's glue wrapper.

  PIXEL-SIZE      - thunk -> (values fb-w fb-h) in framebuffer pixels
  POINT-SIZE      - thunk -> (values w h) in logical points
  CURSOR-POSITION - thunk -> (values x y), cursor in logical points
  TRACKED-BUTTONS - alist (backend-button . imgui-button-index 0/1/2)
  BUTTON-PRESSED-P- (lambda (backend-button) -> generalized-boolean)
  TRACKED-KEYS    - alist (backend-key . im-key keyword, e.g. :key-tab)
  KEY-PRESSED-P   - (lambda (backend-key) -> generalized-boolean)

ImGui widget geometry is in logical points, with the framebuffer scale kept
separate -- so unlike RENDER-NUKLEAR there is no *ui-scale* fudge to apply."
  (let ((io (ig:get-io)))
    (multiple-value-bind (pt-w pt-h) (funcall point-size)
      (multiple-value-bind (px-w px-h) (funcall pixel-size)
        (let ((ds (cffi:foreign-slot-pointer io '(:struct ig:io) 'cl-dear-imgui::display-size))
              (fs (cffi:foreign-slot-pointer io '(:struct ig:io) 'cl-dear-imgui::display-framebuffer-scale)))
          (setf (cffi:foreign-slot-value ds '(:struct ig:vec2) 'cl-dear-imgui::x) (float pt-w 1f0)
                (cffi:foreign-slot-value ds '(:struct ig:vec2) 'cl-dear-imgui::y) (float pt-h 1f0)
                (cffi:foreign-slot-value fs '(:struct ig:vec2) 'cl-dear-imgui::x)
                (if (plusp pt-w) (/ (float px-w 1f0) pt-w) 1f0)
                (cffi:foreign-slot-value fs '(:struct ig:vec2) 'cl-dear-imgui::y)
                (if (plusp pt-h) (/ (float px-h 1f0) pt-h) 1f0)))
        (setf (cffi:foreign-slot-value io '(:struct ig:io) 'cl-dear-imgui::delta-time) (%tick))
        (when *debug-input*
          (format t "imgui: pt=~Ax~A px=~Ax~A~%" pt-w pt-h px-w px-h)
          (force-output))))
    (multiple-value-bind (cx cy) (funcall cursor-position)
      (ig:io-add-mouse-pos-event io (float cx 1f0) (float cy 1f0)))
    (dolist (b tracked-buttons)
      (ig:io-add-mouse-button-event io (cdr b)
                                    (and (funcall button-pressed-p (car b)) t)))
    (dolist (k tracked-keys)
      (ig:io-add-key-event io (cdr k)
                           (and (funcall key-pressed-p (car k)) t)))))
