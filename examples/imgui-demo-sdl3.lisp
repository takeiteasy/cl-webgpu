;;;; examples/imgui-demo-sdl3.lisp
;;;; Dear ImGui rendered via cl-webgpu/imgui -- interactive demo, SDL3 backend.
;;;; The SDL3 counterpart of examples/imgui-demo.lisp: the ImGui demo window
;;;; plus a small custom window, driven by real SDL3 mouse/keyboard/scroll/text
;;;; input via cl-webgpu/imgui-sdl3-glue.

(ql:quickload '(:cl-webgpu :cl-webgpu/wrapper :cl-webgpu/sdl3
                :cl-webgpu/imgui :cl-webgpu/imgui-sdl3-glue))

(defpackage #:imgui-demo-sdl3-example
  (:use #:cl #:cl-webgpu/wrapper)
  (:local-nicknames (#:ig #:cl-dear-imgui))
  (:import-from #:cl-webgpu #:load-wgpu-libraries)
  (:import-from #:cl-webgpu/sdl3
                #:load-sdl3-library #:sdl-get-wgpu-surface)
  (:import-from #:cl-webgpu/imgui
                #:make-imgui-renderer #:render-imgui #:free-imgui-renderer)
  (:import-from #:cl-webgpu/imgui-sdl3-glue
                #:install-input-callbacks #:remove-input-callbacks #:imgui-new-frame))

(in-package #:imgui-demo-sdl3-example)

;; Window size is in SDL3 "points"; with :HIGH-PIXEL-DENSITY the framebuffer is
;; a denser grid. CONFIGURE-SURFACE wants framebuffer pixels; ImGui works in
;; logical points and carries the framebuffer scale separately (set by
;; IMGUI-NEW-FRAME), so -- unlike the nuklear demo -- there is no *ui-scale*.
(defparameter *window-width*  1000)
(defparameter *window-height* 700)
(defvar *width*)
(defvar *height*)
(defvar *slider-value* 0.5)

(defun load-libraries ()
  (let* ((base (asdf:system-source-directory :cl-webgpu))
         (shim (namestring (merge-pathnames #P"shim/" base)))
         (wgpu (namestring (merge-pathnames #P"deps/wgpu-native/target/release/" base))))
    (cl-webgpu:load-wgpu-libraries :wgpu-path wgpu :shim-path shim)
    (load-sdl3-library :path shim)))

(defun window-pixel-size (window)
  (cffi:with-foreign-objects ((w :int) (h :int))
    (sdl3-ffi.functions:sdl-get-window-size-in-pixels (autowrap:ptr window) w h)
    (values (cffi:mem-ref w :int) (cffi:mem-ref h :int))))

(defun build-ui ()
  (ig:show-demo-window (cffi:null-pointer))
  (when (ig:begin "cl-webgpu/imgui" (cffi:null-pointer) 0)
    (ig:text "Rendered by cl-webgpu/imgui on wgpu-native (SDL3).")
    (cffi:with-foreign-object (v :float)
      (setf (cffi:mem-ref v :float) (float *slider-value* 1f0))
      (ig:slider-float "value" v 0f0 1f0)
      (setf *slider-value* (cffi:mem-ref v :float)))
    (when (ig:button "Click me")
      (format t "Button clicked! slider = ~,2F~%" *slider-value*)))
  (ig:end))

(defun render-frame (device surface queue renderer window)
  (let ((view (acquire-frame-texture-view surface)))
    (when view
      (unwind-protect
          (progn
            (imgui-new-frame window)
            (build-ui)
            (ig:render)
            (with-gpu-command-encoder (encoder device)
              (with-render-pass (pass encoder view :clear-r 0.1d0 :clear-g 0.1d0 :clear-b 0.11d0)
                (render-imgui renderer (ig:get-draw-data) pass queue)
                (end-and-submit encoder pass queue surface))))
        (release view)))))

(defun poll-quit-p (ev)
  "Drain the SDL event queue; T on quit/close/ESC. The imgui-sdl3-glue event
watch has already skimmed scroll/text-input non-destructively."
  (let ((quit nil))
    (loop while (/= 0 (sdl3:next-event ev :poll))
          do (case (sdl3:get-event-type ev)
               ((:quit :window-close-requested) (setf quit t))
               (:key-down
                (when (sdl3:scancode= (plus-c:c-ref ev sdl3-ffi:sdl-event :key :scancode)
                                      :escape)
                  (setf quit t)))))
    quit))

(defun run ()
  (load-libraries)
  #+sbcl (sb-int:set-floating-point-modes :traps nil)
  (sdl3:init :video)
  (let ((window (sdl3:create-window :title "cl-webgpu/imgui demo (SDL3)"
                                    :w *window-width* :h *window-height*
                                    :flags '(:high-pixel-density :resizable))))
    (multiple-value-bind (px-w px-h) (window-pixel-size window)
      (setf *width* px-w *height* px-h))
    (sdl3:start-text-input window)
    (unwind-protect
        (with-gpu* ((inst    (make-gpu-instance))
                    (adapter (request-gpu-adapter inst))
                    (device  (request-gpu-device inst adapter))
                    (queue   (get-device-queue device))
                    (surface (make-instance 'gpu-surface
                                            :handle (sdl-get-wgpu-surface (handle inst) window))))
          (let ((fmt (get-surface-format surface adapter)))
            (configure-surface surface device fmt *width* *height*)
            ;; Call order: CREATE-CONTEXT, MAKE-IMGUI-RENDERER, first
            ;; IMGUI-NEW-FRAME. No hand-baked font atlas.
            (ig:create-context (cffi:null-pointer))
            (let ((renderer (make-imgui-renderer device queue fmt)))
              (install-input-callbacks window)
              (unwind-protect
                  (sdl3:with-sdl-event (ev)
                    (format t "Running imgui-demo-sdl3 -- resize/scroll/type, close window or ESC to exit~%")
                    (loop until (poll-quit-p ev)
                          do (multiple-value-bind (px-w px-h) (window-pixel-size window)
                               (when (and (plusp px-w)
                                          (or (/= px-w *width*) (/= px-h *height*)))
                                 (setf *width* px-w *height* px-h)
                                 (configure-surface surface device fmt *width* *height*)))
                             (render-frame device surface queue renderer window)
                             (sleep 0.016)))
                (remove-input-callbacks)
                (free-imgui-renderer renderer)
                (ig:destroy-context (cffi:null-pointer))))))
      (sdl3:destroy-window window)
      (sdl3:quit)
      (format t "Done.~%"))))

#+sbcl (sdl3:make-this-thread-main #'run)
#-sbcl (run)
