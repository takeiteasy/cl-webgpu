(defpackage #:cl-webgpu/nuklear-input-common
  (:use #:cl)
  (:export #:*debug-input*
           #:*scroll-x* #:*scroll-y* #:*text-buffer*
           #:accumulate-scroll #:accumulate-char #:clear-accumulators
           #:pump-nuklear-frame))

(in-package #:cl-webgpu/nuklear-input-common)

;;;; ---------------------------------------------------------------------------
;;;; Shared Nuklear input plumbing for the per-windowing-backend glue systems
;;;; (cl-webgpu/nuklear-glfw-glue, cl-webgpu/nuklear-sdl3-glue).
;;;;
;;;; Both backends have the same shape: scroll and typed text arrive on
;;;; top-level C callbacks (GLFW's DEF-*-CALLBACK forms; SDL's event watch),
;;;; which can't be handed a Nuklear context, so they accumulate into the
;;;; special vars below; then once per frame the backend polls cursor / mouse
;;;; buttons / keyboard directly and drains the accumulators into the context
;;;; with the nk-input-* sequence. Only the polling primitives and the
;;;; key/button name tables differ -- PUMP-NUKLEAR-FRAME takes those as
;;;; closures and tables, so each glue file is just its keymaps + callback
;;;; registration + a thin NUKLEAR-NEW-FRAME wrapper.
;;;;
;;;; The accumulators are process-global, so only one window's input can be
;;;; tracked at a time -- fine for this codebase's single-window apps.
;;;; ---------------------------------------------------------------------------

(defvar *debug-input* nil
  "When non-nil, PUMP-NUKLEAR-FRAME prints per-frame cursor/scale diagnostics.")

(defvar *scroll-x* 0.0d0 "Accumulated horizontal scroll since the last frame.")
(defvar *scroll-y* 0.0d0 "Accumulated vertical scroll since the last frame.")
(defvar *text-buffer*
  (make-array 0 :element-type 'character :adjustable t :fill-pointer 0)
  "Characters typed since the last frame, drained by PUMP-NUKLEAR-FRAME.")

(defun accumulate-scroll (dx dy)
  "Add a scroll delta. Call from the backend's scroll callback/watch."
  (incf *scroll-x* dx)
  (incf *scroll-y* dy))

(defun accumulate-char (char)
  "Append one typed CHARACTER. Call from the backend's char callback/watch."
  (vector-push-extend char *text-buffer*))

(defun clear-accumulators ()
  "Reset scroll/text accumulators. Called at the end of each PUMP-NUKLEAR-FRAME;
also useful when installing/removing callbacks to drop stale input."
  (setf *scroll-x* 0.0d0
        *scroll-y* 0.0d0
        (fill-pointer *text-buffer*) 0))

(defun pump-nuklear-frame (ctx &key pixel-size point-size cursor-position
                                    tracked-buttons button-pressed-p
                                    tracked-keys key-pressed-p
                                    (debug-when (constantly t)))
  "Pump one frame of backend input into the Nuklear context CTX.

Keyword args are the backend-specific pieces:
  PIXEL-SIZE      - thunk -> (values fb-w fb-h) in framebuffer pixels
  POINT-SIZE      - thunk -> (values w h) in logical points
  CURSOR-POSITION - thunk -> (values x y), cursor in logical points
  TRACKED-BUTTONS - alist (backend-button . nk-button-keyword)
  BUTTON-PRESSED-P- (lambda (backend-button) -> generalized-boolean)
  TRACKED-KEYS    - alist (backend-key . nk-key-keyword)
  KEY-PRESSED-P   - (lambda (backend-key) -> generalized-boolean)
  DEBUG-WHEN      - thunk gating the *DEBUG-INPUT* print (default: always)

Cursor/click coords are scaled from points to framebuffer pixels to match
RENDER-NUKLEAR's projection. Drains and clears the scroll/text accumulators."
  (multiple-value-bind (px-w px-h) (funcall pixel-size)
    (multiple-value-bind (pt-w pt-h) (funcall point-size)
      (let ((scale-x (if (plusp pt-w) (/ px-w pt-w) 1))
            (scale-y (if (plusp pt-h) (/ px-h pt-h) 1)))
        (nuklear::nk-input-begin ctx)
        (multiple-value-bind (cx cy) (funcall cursor-position)
          (let ((mx (round (* cx scale-x)))
                (my (round (* cy scale-y))))
            (when (and *debug-input* (funcall debug-when))
              (format t "px=~Ax~A pt=~Ax~A scale=~A,~A cursor=~A,~A -> ~A,~A~%"
                      px-w px-h pt-w pt-h scale-x scale-y cx cy mx my)
              (force-output))
            (nuklear::nk-input-motion ctx mx my)
            (dolist (b tracked-buttons)
              (nuklear::nk-input-button ctx (cdr b) mx my
                                        (if (funcall button-pressed-p (car b)) 1 0)))))
        ;; WITH-VEC2's single-arg (FLOAT X) only coerces rationals -- narrow the
        ;; accumulated :DOUBLE scroll deltas to single-float before the nk-vec2
        ;; struct (C float fields) is filled.
        (nuklear::with-vec2 (v (float *scroll-x* 1.0) (float *scroll-y* 1.0))
          (nuklear::nk-input-scroll ctx v))
        (loop for c across *text-buffer*
              ;; nk-input-char's arg1 is CFFI :char (an integer type) -- pass
              ;; the char-code, a CL character object doesn't coerce.
              do (nuklear::nk-input-char ctx (char-code c)))
        (dolist (k tracked-keys)
          (nuklear::nk-input-key ctx (cdr k)
                                 (if (funcall key-pressed-p (car k)) 1 0)))
        (nuklear::nk-input-end ctx)
        (clear-accumulators)))))
