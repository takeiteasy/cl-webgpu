;;;; examples/nuklear-static.lisp
;;;; Nuklear GUI rendered via cl-webgpu/nuklear — static demo (no input handling).
;;;; Displays a panel with a label and a button using fixed synthetic state.

(ql:quickload '(:cl-webgpu :cl-webgpu/wrapper :cl-webgpu/glfw :cl-webgpu/nuklear))

;; ============================================================================
;; Application package
;; ============================================================================

(defpackage #:nuklear-static-example
  (:use #:cl #:cl-webgpu/wrapper)
  (:import-from #:cl-webgpu #:load-wgpu-libraries)
  (:import-from #:cl-webgpu/glfw
                #:initialize #:terminate
                #:create-window #:destroy-window
                #:poll-events #:window-should-close-p
                #:glfw-create-window-wgpu-surface
                #:load-glfw-library))

(in-package #:nuklear-static-example)

(defparameter *width*  640)
(defparameter *height* 480)

(defun load-libraries ()
  (let* ((base  (asdf:system-source-directory :cl-webgpu))
         (shim  (namestring (merge-pathnames #P"shim/" base)))
         (wgpu  (namestring (merge-pathnames #P"deps/wgpu-native/target/release/" base))))
    (cl-webgpu:load-wgpu-libraries :wgpu-path wgpu :shim-path shim)
    (load-glfw-library :path shim)))

(defun render-frame (device surface pipeline queue renderer ctx)
  (cffi:with-foreign-object (st '(:struct cl-webgpu:wgpu-surface-texture))
    (cl-webgpu:wgpu-surface-get-current-texture (handle surface) st)
    (let ((tex    (cffi:foreign-slot-value st '(:struct cl-webgpu:wgpu-surface-texture) 'cl-webgpu:texture))
          (status (cffi:mem-ref (cffi:foreign-slot-pointer st '(:struct cl-webgpu:wgpu-surface-texture)
                                                           'cl-webgpu:status) :uint32)))
      (when (and (not (cffi:null-pointer-p tex)) (or (= status 1) (= status 2)))
        (with-wgpu-struct (vdesc '(:struct cl-webgpu:wgpu-texture-view-descriptor))
          (let ((view (cl-webgpu:wgpu-texture-create-view tex vdesc)))
            (unwind-protect
                (with-gpu-command-encoder (encoder device)
                  (with-render-pass (pass encoder view :clear-r 0.2d0 :clear-g 0.2d0 :clear-b 0.2d0)
                    ;; Build synthetic UI (no input — just static geometry)
                    (nuklear::nk-begin ctx "Demo"
                                       (cffi:with-foreign-object (r '(:struct nuklear::nk-rect))
                                         (setf (cffi:foreign-slot-value r '(:struct nuklear::nk-rect) 'nuklear::x) 50.0
                                               (cffi:foreign-slot-value r '(:struct nuklear::nk-rect) 'nuklear::y) 50.0
                                               (cffi:foreign-slot-value r '(:struct nuklear::nk-rect) 'nuklear::w) 200.0
                                               (cffi:foreign-slot-value r '(:struct nuklear::nk-rect) 'nuklear::h) 150.0)
                                         r)
                                       (logior 1 2 64)) ; border + movable + title
                    (cffi:with-foreign-string (s "Hello from cl-webgpu/nuklear!")
                      (nuklear::nk-label ctx s :nk-text-left))
                    (nuklear::nk-button-label ctx "Click me")
                    (nuklear::nk-end ctx)
                    ;; Render to the pass
                    (cl-webgpu/nuklear:render-nuklear renderer ctx pass *width* *height*
                                                      (make-instance 'gpu-queue :handle
                                                                     (cl-webgpu:wgpu-device-get-queue (handle device)))))
                  (let ((q (make-instance 'gpu-queue :handle (cl-webgpu:wgpu-device-get-queue (handle device)))))
                    (end-and-submit encoder pass q surface)))
              (cl-webgpu:wgpu-texture-view-release view))))))))

(defun run ()
  (load-libraries)
  #+sbcl (sb-int:set-floating-point-modes :traps nil)
  (cl-glfw3:initialize)
  (let ((window (cl-glfw3:create-window :width *width* :height *height*
                                        :title "Nuklear Static Demo"
                                        :client-api :no-api
                                        :resizable nil)))
    (unwind-protect
        (with-gpu-instance (inst)
          (with-gpu-adapter (adapter inst)
            (with-gpu-device (device inst adapter)
              (let* ((raw-surface (glfw-create-window-wgpu-surface (handle inst) window))
                     (surface     (make-instance 'gpu-surface :handle raw-surface))
                     (fmt         (get-surface-format surface adapter)))
                (unwind-protect
                    (progn
                      (configure-surface surface device fmt *width* *height*)
                      ;; Init nuklear context with default font atlas
                      (cffi:with-foreign-objects ((ctx   '(:struct nuklear::nk-context))
                                                  (atlas '(:struct nuklear::nk-font-atlas))
                                                  (aw    :int) (ah :int))
                        (nuklear::nk-font-atlas-init-default atlas)
                        (nuklear::nk-font-atlas-begin atlas)
                        (let* ((font   (nuklear::nk-font-atlas-add-default atlas 13.0 (cffi:null-pointer)))
                               (pixels (nuklear::nk-font-atlas-bake atlas aw ah :nk-font-atlas-rgba32))
                               (atlas-w (cffi:mem-ref aw :int))
                               (atlas-h (cffi:mem-ref ah :int))
                               (queue   (make-instance 'gpu-queue
                                                       :handle (cl-webgpu:wgpu-device-get-queue (handle device))))
                               (renderer (cl-webgpu/nuklear:make-nuklear-renderer
                                          device queue *width* *height* fmt
                                          atlas pixels atlas-w atlas-h)))
                          (nuklear::nk-font-atlas-cleanup atlas)
                          ;; Init context with the baked font
                          (let ((handle-ptr (cffi:foreign-slot-pointer font '(:struct nuklear::nk-font) 'nuklear::handle)))
                            (nuklear::nk-init-default ctx handle-ptr))
                          (unwind-protect
                              (progn
                                (format t "Running nuklear-static demo — close window to exit~%")
                                (loop until (window-should-close-p window)
                                      do (poll-events)
                                         (render-frame device surface nil queue renderer ctx)
                                         (sleep 0.016)))
                            (cl-webgpu/nuklear:free-nuklear-renderer renderer)
                            (nuklear::nk-free ctx)
                            (nuklear::nk-font-atlas-clear atlas)
                            (release queue)))))
                  (release surface))))))
      (destroy-window window)
      (terminate)
      (format t "Done.~%"))))

(run)
