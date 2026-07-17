(defpackage #:cl-webgpu/nuklear-glfw-glue
  (:use #:cl)
  (:export #:install-input-callbacks
           #:nuklear-new-frame
           #:*debug-input*))

(in-package #:cl-webgpu/nuklear-glfw-glue)

;;;; ---------------------------------------------------------------------------
;;;; GLFW -> Nuklear input glue (weasel #70)
;;;;
;;;; GLFW's scroll/char callbacks are top-level C callbacks (CL-GLFW3's
;;;; DEF-*-CALLBACK forms), not closures, so they can't be handed a Nuklear
;;;; context directly -- they accumulate into the special vars below instead,
;;;; which NUKLEAR-NEW-FRAME drains each frame. This means only one window's
;;;; input can be tracked at a time; fine for this codebase's single-window
;;;; apps, but a real limitation if that ever changes.
;;;; ---------------------------------------------------------------------------

(defvar *debug-input* nil
  "When non-nil, NUKLEAR-NEW-FRAME prints per-frame cursor/scale diagnostics.")
(defvar *scroll-x* 0.0d0)
(defvar *scroll-y* 0.0d0)
(defvar *text-buffer* (make-array 0 :element-type 'character :adjustable t :fill-pointer 0))

(cl-webgpu/glfw:def-scroll-callback %on-scroll (window x y)
  (declare (ignore window))
  (incf *scroll-x* x)
  (incf *scroll-y* y))

(cl-webgpu/glfw:def-char-callback %on-char (window char)
  (declare (ignore window))
  (vector-push-extend char *text-buffer*))

(defun install-input-callbacks (window)
  "Register the GLFW scroll/char callbacks that feed NUKLEAR-NEW-FRAME.
Single-window: see the note on *SCROLL-X*/*SCROLL-Y*/*TEXT-BUFFER* above."
  (cl-webgpu/glfw:set-scroll-callback '%on-scroll window)
  (cl-webgpu/glfw:set-char-callback '%on-char window))

(defparameter *tracked-keys*
  '((:backspace       . :nk-key-backspace)
    (:delete          . :nk-key-del)
    (:enter           . :nk-key-enter)
    (:tab             . :nk-key-tab)
    (:left            . :nk-key-left)
    (:right           . :nk-key-right)
    (:up              . :nk-key-up)
    (:down            . :nk-key-down)
    (:left-shift      . :nk-key-shift)
    (:right-shift     . :nk-key-shift)
    (:left-control    . :nk-key-ctrl)
    (:right-control   . :nk-key-ctrl))
  "GLFW key -> Nuklear key, polled once per frame via GET-KEY.")

(defparameter *tracked-buttons*
  ;; CL-GLFW3's MOUSE enum has no :MIDDLE keyword -- only :LEFT/:RIGHT aliases
  ;; plus numbered :1-:8 (GLFW's raw button indices). GLFW_MOUSE_BUTTON_MIDDLE
  ;; is button index 2, i.e. :3 in this 0-indexed enum.
  '((:left . :nk-button-left)
    (:3    . :nk-button-middle)
    (:right . :nk-button-right)))

(defun nuklear-new-frame (ctx window)
  "Pump one frame of GLFW input into the Nuklear context CTX. Call once per
frame, after POLL-EVENTS and before building any widgets."
  (destructuring-bind (fb-w fb-h) (cl-webgpu/glfw:get-framebuffer-size window)
    (destructuring-bind (win-w win-h) (cl-webgpu/glfw:get-window-size window)
      ;; GLFW cursor position is reported in points; RENDER-NUKLEAR's
      ;; projection is in framebuffer pixels (see the HiDPI note in
      ;; examples/nuklear-static.lisp) -- scale cursor/click coords up to match.
      (let ((fb-scale-x (if (plusp win-w) (/ fb-w win-w) 1))
            (fb-scale-y (if (plusp win-h) (/ fb-h win-h) 1)))
        (nuklear::nk-input-begin ctx)
        (destructuring-bind (cx cy) (cl-webgpu/glfw:get-cursor-position window)
          (let ((px (round (* cx fb-scale-x)))
                (py (round (* cy fb-scale-y))))
            (when (and *debug-input*
                       (eq (cl-webgpu/glfw:get-mouse-button :left window) :press))
              (format t "fb=~Ax~A win=~Ax~A scale=~A,~A cursor=~A,~A -> px=~A,~A~%"
                      fb-w fb-h win-w win-h fb-scale-x fb-scale-y cx cy px py)
              (force-output))
            (nuklear::nk-input-motion ctx px py)
            (dolist (b *tracked-buttons*)
              (let ((down (eq (cl-webgpu/glfw:get-mouse-button (car b) window) :press)))
                (nuklear::nk-input-button ctx (cdr b) px py (if down 1 0))))))
        ;; WITH-VEC2's (FLOAT X) is single-arg, so it only coerces rationals --
        ;; *SCROLL-X*/*SCROLL-Y* accumulate GLFW's :DOUBLE scroll deltas and
        ;; must be narrowed to single-float explicitly before the nk-vec2
        ;; struct (whose fields are C float) gets a double-float slammed in.
        (nuklear::with-vec2 (v (float *scroll-x* 1.0) (float *scroll-y* 1.0))
          (nuklear::nk-input-scroll ctx v))
        (loop for c across *text-buffer*
              ;; nk-input-char's arg1 is CFFI :char (an integer type) -- a CL
              ;; character object doesn't coerce, must pass its char-code.
              do (nuklear::nk-input-char ctx (char-code c)))
        (dolist (k *tracked-keys*)
          (nuklear::nk-input-key ctx (cdr k)
                                  (if (eq (cl-webgpu/glfw:get-key (car k) window) :press) 1 0)))
        (nuklear::nk-input-end ctx)
        (setf *scroll-x* 0.0d0 *scroll-y* 0.0d0)
        (setf (fill-pointer *text-buffer*) 0)))))
