(defpackage #:cl-webgpu/nuklear-sdl3-glue
  (:use #:cl)
  (:import-from #:cl-webgpu/nuklear-input-common
                #:*debug-input* #:accumulate-scroll #:accumulate-char
                #:clear-accumulators #:pump-nuklear-frame)
  (:export #:install-input-callbacks
           #:remove-input-callbacks
           #:nuklear-new-frame
           #:*debug-input*))

(in-package #:cl-webgpu/nuklear-sdl3-glue)

;;;; ---------------------------------------------------------------------------
;;;; SDL3 -> Nuklear input glue
;;;;
;;;; Mirrors nuklear/glfw-input.lisp; shared plumbing lives in
;;;; cl-webgpu/nuklear-input-common. SDL3's scroll/text-input arrive as queue
;;;; events, which the app's own event loop would consume before this glue ever
;;;; saw them -- so instead of polling the queue here we register an
;;;; SDL_AddEventWatch callback. The watch runs for every event as it is
;;;; queued, its return value is ignored, and it does NOT remove the event, so
;;;; the app's with-event-loop / next-event still sees :quit, resize, etc.
;;;;
;;;; SDL may invoke the watch from a different thread than the render loop
;;;; (SDL_AddEventWatch docs). For the single-threaded example apps here it
;;;; fires on the thread pumping events (the main thread); the unsynchronised
;;;; accumulate/drain in nuklear-input-common is fine for that. A genuinely
;;;; multi-threaded host would need a lock.
;;;; ---------------------------------------------------------------------------

;; SDL_AddEventWatch / SDL_RemoveEventWatch. cl-sdl3 already loads libSDL3, so
;; these symbols resolve against the SDL3 the process has loaded.
(cffi:defcfun ("SDL_AddEventWatch" %sdl-add-event-watch) :bool
  (filter :pointer) (userdata :pointer))
(cffi:defcfun ("SDL_RemoveEventWatch" %sdl-remove-event-watch) :void
  (filter :pointer) (userdata :pointer))

;; SDL3's SDL_GetMouseState takes float* out-params (SDL2 used int*). cl-sdl3's
;; SDL3:MOUSE-STATE still binds them as :int and reads the float bytes back as
;; an integer -- garbage. Bind it ourselves with the correct type. (tracker #7)
(cffi:defcfun ("SDL_GetMouseState" %sdl-get-mouse-state) :uint32
  (x (:pointer :float)) (y (:pointer :float)))

(cffi:defcallback %event-watch :bool ((userdata :pointer) (event :pointer))
  (declare (ignore userdata))
  (plus-c:c-let ((e sdl3-ffi:sdl-event :from event))
    (let ((type (e :type)))
      (cond
        ((= type sdl3-ffi:+sdl-event-mouse-wheel+)
         (accumulate-scroll (e :wheel :x) (e :wheel :y)))
        ((= type sdl3-ffi:+sdl-event-text-input+)
         ;; :text is a const char* UTF-8 string; append each character.
         (let ((s (plus-c:c-ref e sdl3-ffi:sdl-event :text :text string)))
           (when s
             (loop for c across s do (accumulate-char c))))))))
  ;; Return value is ignored by SDL for a watch, but the type is bool.
  nil)

(defun install-input-callbacks (&optional window)
  "Register the SDL3 event watch that feeds NUKLEAR-NEW-FRAME.
Single-window: see the note in cl-webgpu/nuklear-input-common.
WINDOW is accepted for signature parity with the GLFW glue; SDL text-input
events are enabled per-window with SDL3:START-TEXT-INPUT by the caller."
  (declare (ignore window))
  (%sdl-add-event-watch (cffi:callback %event-watch) (cffi:null-pointer))
  (clear-accumulators))

(defun remove-input-callbacks ()
  "Unregister the event watch installed by INSTALL-INPUT-CALLBACKS."
  (%sdl-remove-event-watch (cffi:callback %event-watch) (cffi:null-pointer)))

;;; SDL3 scancode keyword -> Nuklear key, polled once per frame via
;;; SDL3:KEYBOARD-STATE-P. SDL scancode names differ from GLFW's key names, so
;;; this is a distinct table (e.g. SDL :return where GLFW uses :enter, and
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
  ;; One SDL_GetMouseState call per frame; the closures below read the cached
  ;; result so cursor position and button bits stay consistent.
  (cffi:with-foreign-objects ((fx :float) (fy :float))
    (let ((buttons (%sdl-get-mouse-state fx fy))
          (mx (cffi:mem-ref fx :float))
          (my (cffi:mem-ref fy :float)))
      (pump-nuklear-frame
       ctx
       :pixel-size (lambda () (%window-pixel-size window))
       :point-size (lambda () (sdl3:get-window-size window))
       :cursor-position (lambda () (values mx my))
       :tracked-buttons *tracked-buttons*
       :button-pressed-p (lambda (bit) (plusp (logand buttons bit)))
       :tracked-keys *tracked-keys*
       :key-pressed-p (lambda (k) (sdl3:keyboard-state-p k))))))
