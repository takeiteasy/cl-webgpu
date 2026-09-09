(defpackage #:cl-webgpu/nuklear-sdl3-glue
  (:use #:cl)
  (:export #:install-input-callbacks
           #:remove-input-callbacks
           #:nuklear-new-frame
           #:*debug-input*))

(in-package #:cl-webgpu/nuklear-sdl3-glue)

;;;; ---------------------------------------------------------------------------
;;;; SDL3 -> Nuklear input glue
;;;;
;;;; Mirrors nuklear/glfw-input.lisp. SDL3's scroll/text-input arrive as queue
;;;; events, which the app's own event loop would consume before this glue ever
;;;; saw them -- so instead of polling the queue here (which would fight the app
;;;; for events) we register an SDL_AddEventWatch callback. The watch runs for
;;;; every event as it is queued, its return value is ignored, and it does NOT
;;;; remove the event, so the app's with-event-loop / next-event still sees
;;;; :quit, resize, etc. untouched.
;;;;
;;;; The watch is a top-level C callback, not a closure, so (as with the GLFW
;;;; glue) it accumulates into the special vars below, which NUKLEAR-NEW-FRAME
;;;; drains each frame -- only one window's input can be tracked at a time.
;;;;
;;;; SDL may invoke the watch from a different thread than the render loop
;;;; (SDL_AddEventWatch docs). In practice, for the single-threaded example
;;;; apps here it fires on the thread pumping events (the main thread). The
;;;; unsynchronised accumulate/drain below is fine for that; a genuinely
;;;; multi-threaded host would need a lock.
;;;; ---------------------------------------------------------------------------

(defvar *debug-input* nil
  "When non-nil, NUKLEAR-NEW-FRAME prints per-frame cursor/scale diagnostics.")
(defvar *scroll-x* 0.0d0)
(defvar *scroll-y* 0.0d0)
(defvar *text-buffer* (make-array 0 :element-type 'character :adjustable t :fill-pointer 0))

;; SDL_AddEventWatch / SDL_RemoveEventWatch. cl-sdl3 already loads libSDL3, so
;; these symbols resolve against the SDL3 the process has loaded.
(cffi:defcfun ("SDL_AddEventWatch" %sdl-add-event-watch) :bool
  (filter :pointer) (userdata :pointer))
(cffi:defcfun ("SDL_RemoveEventWatch" %sdl-remove-event-watch) :void
  (filter :pointer) (userdata :pointer))

;; SDL3's SDL_GetMouseState takes float* out-params (SDL2 used int*). cl-sdl3's
;; SDL3:MOUSE-STATE still binds them as :int and reads the float bytes back as
;; an integer -- garbage. Bind it ourselves with the correct type.
(cffi:defcfun ("SDL_GetMouseState" %sdl-get-mouse-state) :uint32
  (x (:pointer :float)) (y (:pointer :float)))

(cffi:defcallback %event-watch :bool ((userdata :pointer) (event :pointer))
  (declare (ignore userdata))
  (plus-c:c-let ((e sdl3-ffi:sdl-event :from event))
    (let ((type (e :type)))
      (cond
        ((= type sdl3-ffi:+sdl-event-mouse-wheel+)
         (incf *scroll-x* (e :wheel :x))
         (incf *scroll-y* (e :wheel :y)))
        ((= type sdl3-ffi:+sdl-event-text-input+)
         ;; :text is a const char* UTF-8 string; append each character.
         (let ((s (plus-c:c-ref e sdl3-ffi:sdl-event :text :text string)))
           (when s
             (loop for c across s do (vector-push-extend c *text-buffer*))))))))
  ;; Return value is ignored by SDL for a watch, but the type is bool.
  nil)

(defun install-input-callbacks (&optional window)
  "Register the SDL3 event watch that feeds NUKLEAR-NEW-FRAME.
Single-window: see the note on *SCROLL-X*/*SCROLL-Y*/*TEXT-BUFFER* above.
WINDOW is accepted for signature parity with the GLFW glue; SDL text-input
events are enabled per-window with SDL3:START-TEXT-INPUT by the caller."
  (declare (ignore window))
  (%sdl-add-event-watch (cffi:callback %event-watch) (cffi:null-pointer)))

(defun remove-input-callbacks ()
  "Unregister the event watch installed by INSTALL-INPUT-CALLBACKS."
  (%sdl-remove-event-watch (cffi:callback %event-watch) (cffi:null-pointer)))

;;; SDL3 scancode keyword -> Nuklear key, polled once per frame via
;;; SDL3:KEYBOARD-STATE-P. SDL keycodes differ from GLFW's, so this is a
;;; distinct table (e.g. SDL uses :return where GLFW uses :enter, and
;;; :lshift/:lctrl rather than :left-shift/:left-control).
(defparameter *tracked-keys*
  '((:backspace . :nk-key-backspace)
    (:delete    . :nk-key-del)
    (:return    . :nk-key-enter)
    (:tab       . :nk-key-tab)
    (:left      . :nk-key-left)
    (:right     . :nk-key-right)
    (:up        . :nk-key-up)
    (:down      . :nk-key-down)
    (:lshift    . :nk-key-shift)
    (:rshift    . :nk-key-shift)
    (:lctrl     . :nk-key-ctrl)
    (:rctrl     . :nk-key-ctrl))
  "SDL3 scancode keyword -> Nuklear key, polled once per frame.")

(defparameter *tracked-buttons*
  ;; SDL_GetMouseState bitmask: bit (button-1). LEFT=1, MIDDLE=2, RIGHT=3.
  '((1 . :nk-button-left)
    (2 . :nk-button-middle)
    (4 . :nk-button-right))
  "SDL mouse-state bitmask bit -> Nuklear button.")

(defun %window-pixel-size (window)
  "(VALUES PIXEL-W PIXEL-H) for WINDOW's framebuffer. SDL3 exposes this
directly, so no manual scale-factor maths (unlike the GLFW path)."
  (cffi:with-foreign-objects ((w :int) (h :int))
    (sdl3-ffi.functions:sdl-get-window-size-in-pixels (autowrap:ptr window) w h)
    (values (cffi:mem-ref w :int) (cffi:mem-ref h :int))))

(defun nuklear-new-frame (ctx window)
  "Pump one frame of SDL3 input into the Nuklear context CTX. Call once per
frame, after the app has pumped SDL events and before building any widgets."
  (multiple-value-bind (px-w px-h) (%window-pixel-size window)
    (multiple-value-bind (pt-w pt-h) (sdl3:get-window-size window)
      ;; SDL mouse position is reported in logical points; RENDER-NUKLEAR's
      ;; projection is in framebuffer pixels -- scale cursor/click coords up.
      (let ((fb-scale-x (if (plusp pt-w) (/ px-w pt-w) 1))
            (fb-scale-y (if (plusp pt-h) (/ px-h pt-h) 1)))
        (nuklear::nk-input-begin ctx)
        (cffi:with-foreign-objects ((fx :float) (fy :float))
          (let* ((buttons (%sdl-get-mouse-state fx fy))
                 (mx (cffi:mem-ref fx :float))
                 (my (cffi:mem-ref fy :float))
                 (cx (round (* mx fb-scale-x)))
                 (cy (round (* my fb-scale-y))))
            (when *debug-input*
              (format t "px=~Ax~A pt=~Ax~A scale=~A,~A mouse=~A,~A -> ~A,~A~%"
                      px-w px-h pt-w pt-h fb-scale-x fb-scale-y mx my cx cy)
              (force-output))
            (nuklear::nk-input-motion ctx cx cy)
            (dolist (b *tracked-buttons*)
              (nuklear::nk-input-button ctx (cdr b) cx cy
                                        (if (plusp (logand buttons (car b))) 1 0)))))
        ;; WITH-VEC2's single-arg (FLOAT X) only coerces rationals -- narrow the
        ;; accumulated :DOUBLE scroll deltas to single-float before the nk-vec2
        ;; struct (C float fields) is filled.
        (nuklear::with-vec2 (v (float *scroll-x* 1.0) (float *scroll-y* 1.0))
          (nuklear::nk-input-scroll ctx v))
        (loop for c across *text-buffer*
              ;; nk-input-char's arg1 is CFFI :char (integer) -- pass char-code.
              do (nuklear::nk-input-char ctx (char-code c)))
        (dolist (k *tracked-keys*)
          (nuklear::nk-input-key ctx (cdr k)
                                 (if (sdl3:keyboard-state-p (car k)) 1 0)))
        (nuklear::nk-input-end ctx)
        (setf *scroll-x* 0.0d0 *scroll-y* 0.0d0)
        (setf (fill-pointer *text-buffer*) 0)))))
