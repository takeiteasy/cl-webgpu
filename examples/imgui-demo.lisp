;;;; examples/imgui-demo.lisp
;;;; Dear ImGui rendered via cl-webgpu/imgui -- interactive demo, GLFW backend.
;;;; Shows the ImGui demo window plus a small custom window (a slider + a
;;;; button), driven by real GLFW mouse/keyboard/scroll/text input via
;;;; cl-webgpu/imgui-glfw-glue.

(ql:quickload '(:cl-webgpu :cl-webgpu/wrapper :cl-webgpu/glfw
                :cl-webgpu/imgui :cl-webgpu/imgui-glfw-glue))

(defpackage #:imgui-demo-example
  (:use #:cl #:cl-webgpu/wrapper)
  (:local-nicknames (#:ig #:cl-dear-imgui))
  (:import-from #:cl-webgpu #:load-wgpu-libraries)
  (:import-from #:cl-webgpu/glfw
                #:get-framebuffer-size
                #:glfw-create-window-wgpu-surface
                #:load-glfw-library)
  (:import-from #:cl-webgpu/imgui
                #:make-imgui-renderer #:render-imgui #:free-imgui-renderer)
  (:import-from #:cl-webgpu/imgui-glfw-glue
                #:install-input-callbacks #:remove-input-callbacks #:imgui-new-frame))

(in-package #:imgui-demo-example)

;; Window size is in GLFW "points"; the framebuffer may be a denser pixel grid
;; on a Retina display. CONFIGURE-SURFACE wants framebuffer pixels; ImGui itself
;; works in logical points and carries the framebuffer scale separately (set by
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
    (load-glfw-library :path shim)))

(defun build-ui ()
  ;; The stock ImGui demo -- exercises text, scrolling, tables, inputs, etc.
  (ig:show-demo-window (cffi:null-pointer))
  ;; A tiny custom window proving our own widgets round-trip input.
  (when (ig:begin "cl-webgpu/imgui" (cffi:null-pointer) 0)
    (ig:text "Rendered by cl-webgpu/imgui on wgpu-native.")
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
            ;; Feed input + IG:NEW-FRAME, build the UI, then IG:RENDER so
            ;; GET-DRAW-DATA is populated for this frame.
            (imgui-new-frame window)
            (build-ui)
            (ig:render)
            (with-gpu-command-encoder (encoder device)
              (with-render-pass (pass encoder view :clear-r 0.1d0 :clear-g 0.1d0 :clear-b 0.11d0)
                (render-imgui renderer (ig:get-draw-data) pass queue)
                (end-and-submit encoder pass queue surface))))
        (release view)))))

(defun run ()
  (load-libraries)
  #+sbcl (sb-int:set-floating-point-modes :traps nil)
  (cl-glfw3:initialize)
  (let ((window (cl-glfw3:create-window :width *window-width* :height *window-height*
                                        :title "cl-webgpu/imgui demo"
                                        :client-api :no-api
                                        :resizable t)))
    (destructuring-bind (fb-w fb-h) (get-framebuffer-size window)
      (setf *width* fb-w *height* fb-h))
    (unwind-protect
        (with-gpu* ((inst    (make-gpu-instance))
                    (adapter (request-gpu-adapter inst))
                    (device  (request-gpu-device inst adapter))
                    (queue   (get-device-queue device))
                    (surface (make-instance 'gpu-surface
                                            :handle (glfw-create-window-wgpu-surface
                                                     (handle inst) window))))
          (let ((fmt (get-surface-format surface adapter)))
            (configure-surface surface device fmt *width* *height*)
            ;; Call order matters: CREATE-CONTEXT, then MAKE-IMGUI-RENDERER
            ;; (which sets ImGuiBackendFlags_RendererHasTextures), then the
            ;; first IMGUI-NEW-FRAME. Do NOT bake the font atlas by hand.
            (ig:create-context (cffi:null-pointer))
            (let ((renderer (make-imgui-renderer device queue fmt)))
              (install-input-callbacks window)
              (unwind-protect
                  (progn
                    (format t "Running imgui-demo -- resize/scroll/type, close window to exit~%")
                    (loop until (cl-webgpu/glfw:window-should-close-p window)
                          do (cl-webgpu/glfw:poll-events)
                             ;; keep the surface matched to the live framebuffer
                             (destructuring-bind (fb-w fb-h) (get-framebuffer-size window)
                               (when (and (plusp fb-w)
                                          (or (/= fb-w *width*) (/= fb-h *height*)))
                                 (setf *width* fb-w *height* fb-h)
                                 (configure-surface surface device fmt *width* *height*)))
                             (render-frame device surface queue renderer window)
                             (sleep 0.016)))
                (remove-input-callbacks)
                (free-imgui-renderer renderer)
                (ig:destroy-context (cffi:null-pointer))))))
      (cl-glfw3:destroy-window window)
      (cl-glfw3:terminate)
      (format t "Done.~%"))))

(run)
