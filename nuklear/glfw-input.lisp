(defpackage #:cl-webgpu/nuklear-glfw-glue
  (:use #:cl)
  (:import-from #:cl-webgpu/nuklear-input-common
                #:*debug-input* #:accumulate-scroll #:accumulate-char
                #:clear-accumulators #:pump-nuklear-frame)
  (:export #:install-input-callbacks
           #:nuklear-new-frame
           #:*debug-input*))

(in-package #:cl-webgpu/nuklear-glfw-glue)

;;;; ---------------------------------------------------------------------------
;;;; GLFW -> Nuklear input glue (weasel #70)
;;;;
;;;; GLFW's scroll/char callbacks are top-level C callbacks (CL-GLFW3's
;;;; DEF-*-CALLBACK forms), not closures, so they accumulate into the shared
;;;; specials in cl-webgpu/nuklear-input-common, which PUMP-NUKLEAR-FRAME drains
;;;; each frame. Only one window's input can be tracked at a time; fine for this
;;;; codebase's single-window apps. See that package for the shared plumbing.
;;;; ---------------------------------------------------------------------------

(cl-webgpu/glfw:def-scroll-callback %on-scroll (window x y)
  (declare (ignore window))
  (accumulate-scroll x y))

(cl-webgpu/glfw:def-char-callback %on-char (window char)
  (declare (ignore window))
  (accumulate-char char))

(defun install-input-callbacks (window)
  "Register the GLFW scroll/char callbacks that feed NUKLEAR-NEW-FRAME.
Single-window: see the note in cl-webgpu/nuklear-input-common."
  (cl-webgpu/glfw:set-scroll-callback '%on-scroll window)
  (cl-webgpu/glfw:set-char-callback '%on-char window)
  (clear-accumulators))

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
  (pump-nuklear-frame
   ctx
   :pixel-size (lambda () (values-list (cl-webgpu/glfw:get-framebuffer-size window)))
   :point-size (lambda () (values-list (cl-webgpu/glfw:get-window-size window)))
   :cursor-position (lambda () (values-list (cl-webgpu/glfw:get-cursor-position window)))
   :tracked-buttons *tracked-buttons*
   :button-pressed-p (lambda (b) (eq (cl-webgpu/glfw:get-mouse-button b window) :press))
   :tracked-keys *tracked-keys*
   :key-pressed-p (lambda (k) (eq (cl-webgpu/glfw:get-key k window) :press))
   :debug-when (lambda () (eq (cl-webgpu/glfw:get-mouse-button :left window) :press))))
