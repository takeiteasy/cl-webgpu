(defpackage #:cl-webgpu/imgui-glfw-glue
  (:use #:cl)
  (:local-nicknames (#:ig #:cl-dear-imgui))
  (:import-from #:cl-webgpu/imgui-input-common
                #:*debug-input* #:pump-imgui-frame #:reset-clock)
  (:export #:install-input-callbacks
           #:remove-input-callbacks
           #:imgui-new-frame
           #:*debug-input*))

(in-package #:cl-webgpu/imgui-glfw-glue)

;;;; ---------------------------------------------------------------------------
;;;; GLFW -> Dear ImGui input glue
;;;;
;;;; Mirrors nuklear/glfw-input.lisp: GLFW's scroll/char callbacks are top-level
;;;; C callbacks (CL-GLFW3's DEF-*-CALLBACK), so they cannot close over a
;;;; context. ImGui's event queue is global to the current context, though, so
;;;; the callbacks push straight into it -- no accumulate/drain step. Cursor,
;;;; buttons and keys are polled once per frame in IMGUI-NEW-FRAME. Single
;;;; window at a time; see cl-webgpu/imgui-input-common.
;;;; ---------------------------------------------------------------------------

(cl-webgpu/glfw:def-scroll-callback %on-scroll (window x y)
  (declare (ignore window))
  (ig:io-add-mouse-wheel-event (ig:get-io) (float x 1f0) (float y 1f0)))

(cl-webgpu/glfw:def-char-callback %on-char (window char)
  (declare (ignore window))
  (ig:io-add-input-character (ig:get-io) (char-code char)))

(defun install-input-callbacks (window)
  "Register the GLFW scroll/char callbacks that feed IMGUI-NEW-FRAME.
Single-window: see the note in cl-webgpu/imgui-input-common."
  (cl-webgpu/glfw:set-scroll-callback '%on-scroll window)
  (cl-webgpu/glfw:set-char-callback '%on-char window)
  (reset-clock))

(defun remove-input-callbacks ()
  "Unregister the scroll/char callbacks. Accepted for parity with the SDL3 glue;
GLFW clears per-window callbacks when the window is destroyed, so this is a
no-op placeholder unless a later CL-GLFW3 exposes callback removal."
  (values))

(defparameter *tracked-keys*
  '((:backspace     . :key-backspace)
    (:delete        . :key-delete)
    (:enter         . :key-enter)
    (:tab           . :key-tab)
    (:space         . :key-space)
    (:escape        . :key-escape)
    (:left          . :key-left-arrow)
    (:right         . :key-right-arrow)
    (:up            . :key-up-arrow)
    (:down          . :key-down-arrow)
    (:home          . :key-home)
    (:end           . :key-end)
    (:page-up       . :key-page-up)
    (:page-down     . :key-page-down)
    (:left-shift    . :key-left-shift)
    (:right-shift   . :key-right-shift)
    (:left-control  . :key-left-ctrl)
    (:right-control . :key-right-ctrl)
    (:left-alt      . :key-left-alt)
    (:left-super    . :key-left-super))
  "GLFW key -> ImGui im-key, polled once per frame via GET-KEY.")

(defparameter *tracked-buttons*
  ;; ImGui mouse button indices: 0 = left, 1 = right, 2 = middle. CL-GLFW3's
  ;; MOUSE enum has no :MIDDLE keyword -- middle is raw button index 2, :3 here.
  '((:left  . 0)
    (:right . 1)
    (:3     . 2)))

(defun imgui-new-frame (window)
  "Pump one frame of GLFW input into the current ImGui context, then call
IG:NEW-FRAME. Call once per frame, after POLL-EVENTS and before building UI."
  (pump-imgui-frame
   :pixel-size (lambda () (values-list (cl-webgpu/glfw:get-framebuffer-size window)))
   :point-size (lambda () (values-list (cl-webgpu/glfw:get-window-size window)))
   :cursor-position (lambda () (values-list (cl-webgpu/glfw:get-cursor-position window)))
   :tracked-buttons *tracked-buttons*
   :button-pressed-p (lambda (b) (eq (cl-webgpu/glfw:get-mouse-button b window) :press))
   :tracked-keys *tracked-keys*
   :key-pressed-p (lambda (k) (eq (cl-webgpu/glfw:get-key k window) :press)))
  (ig:new-frame))
