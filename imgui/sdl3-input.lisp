(defpackage #:cl-webgpu/imgui-sdl3-glue
  (:use #:cl)
  (:local-nicknames (#:ig #:cl-dear-imgui))
  (:import-from #:cl-webgpu/imgui-input-common
                #:*debug-input* #:pump-imgui-frame #:reset-clock)
  (:export #:install-input-callbacks
           #:remove-input-callbacks
           #:imgui-new-frame
           #:*debug-input*))

(in-package #:cl-webgpu/imgui-sdl3-glue)

;;;; ---------------------------------------------------------------------------
;;;; SDL3 -> Dear ImGui input glue
;;;;
;;;; Mirrors nuklear/sdl3-input.lisp. SDL3's scroll/text events arrive on the
;;;; event queue, which the app's own loop would drain first, so this registers
;;;; a non-destructive SDL_AddEventWatch. The watch pushes wheel + text straight
;;;; into ImGui's per-context event queue; cursor / buttons / keys are polled
;;;; once per frame in IMGUI-NEW-FRAME.
;;;;
;;;; SDL may run the watch on a different thread than the render loop. For the
;;;; single-threaded example apps here it fires on the main (event-pumping)
;;;; thread, so pushing to ImGui's queue unsynchronised is fine. A genuinely
;;;; multi-threaded host would need a lock.
;;;; ---------------------------------------------------------------------------

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
    (let ((type (e :type))
          (io (ig:get-io)))
      (cond
        ((= type sdl3-ffi:+sdl-event-mouse-wheel+)
         (ig:io-add-mouse-wheel-event io
                                      (float (e :wheel :x) 1f0)
                                      (float (e :wheel :y) 1f0)))
        ((= type sdl3-ffi:+sdl-event-text-input+)
         (let ((s (plus-c:c-ref e sdl3-ffi:sdl-event :text :text string)))
           (when s
             (loop for c across s do (ig:io-add-input-character io (char-code c)))))))))
  nil)

(defun install-input-callbacks (&optional window)
  "Register the SDL3 event watch that feeds IMGUI-NEW-FRAME.
WINDOW is accepted for parity with the GLFW glue; the caller enables text input
per-window with SDL3:START-TEXT-INPUT. Single-window: see
cl-webgpu/imgui-input-common."
  (declare (ignore window))
  (%sdl-add-event-watch (cffi:callback %event-watch) (cffi:null-pointer))
  (reset-clock))

(defun remove-input-callbacks ()
  "Unregister the event watch installed by INSTALL-INPUT-CALLBACKS."
  (%sdl-remove-event-watch (cffi:callback %event-watch) (cffi:null-pointer)))

;;; SDL3 scancode keyword -> ImGui im-key, polled once per frame via
;;; SDL3:KEYBOARD-STATE-P. SDL scancode names differ from GLFW's (e.g. :return
;;; where GLFW uses :enter, :lshift/:lctrl rather than :left-shift).
(defparameter *tracked-keys*
  '((:backspace . :key-backspace)
    (:delete    . :key-delete)
    (:return    . :key-enter)
    (:tab       . :key-tab)
    (:space     . :key-space)
    (:escape    . :key-escape)
    (:left      . :key-left-arrow)
    (:right     . :key-right-arrow)
    (:up        . :key-up-arrow)
    (:down      . :key-down-arrow)
    (:home      . :key-home)
    (:end       . :key-end)
    (:pageup    . :key-page-up)
    (:pagedown  . :key-page-down)
    (:lshift    . :key-left-shift)
    (:rshift    . :key-right-shift)
    (:lctrl     . :key-left-ctrl)
    (:rctrl     . :key-right-ctrl)
    (:lalt      . :key-left-alt)
    (:lgui      . :key-left-super))
  "SDL3 scancode keyword -> ImGui im-key, polled once per frame.")

(defparameter *tracked-buttons*
  ;; SDL_GetMouseState bitmask bit -> ImGui button index. SDL: LEFT=bit0,
  ;; MIDDLE=bit1, RIGHT=bit2. ImGui: 0=left, 1=right, 2=middle.
  '((1 . 0)
    (4 . 1)
    (2 . 2))
  "SDL mouse-state bitmask bit -> ImGui button index.")

(defun %window-pixel-size (window)
  "(VALUES PIXEL-W PIXEL-H) for WINDOW's framebuffer, via SDL3 directly."
  (cffi:with-foreign-objects ((w :int) (h :int))
    (sdl3-ffi.functions:sdl-get-window-size-in-pixels (autowrap:ptr window) w h)
    (values (cffi:mem-ref w :int) (cffi:mem-ref h :int))))

(defun imgui-new-frame (window)
  "Pump one frame of SDL3 input into the current ImGui context, then call
IG:NEW-FRAME. Call once per frame, after the app has pumped SDL events."
  (cffi:with-foreign-objects ((fx :float) (fy :float))
    (let ((buttons (%sdl-get-mouse-state fx fy))
          (mx (cffi:mem-ref fx :float))
          (my (cffi:mem-ref fy :float)))
      (pump-imgui-frame
       :pixel-size (lambda () (%window-pixel-size window))
       :point-size (lambda () (sdl3:get-window-size window))
       :cursor-position (lambda () (values mx my))
       :tracked-buttons *tracked-buttons*
       :button-pressed-p (lambda (bit) (plusp (logand buttons bit)))
       :tracked-keys *tracked-keys*
       :key-pressed-p (lambda (k) (sdl3:keyboard-state-p k)))))
  (ig:new-frame))
