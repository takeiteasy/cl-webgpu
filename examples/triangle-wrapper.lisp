;;;; examples/triangle-wrapper.lisp
;;;; WebGPU triangle using cl-webgpu/wrapper + cl-webgpu/shader DSL

(ql:quickload '(:cl-webgpu :cl-webgpu/wrapper :cl-webgpu/glfw :cl-webgpu/shader))

;; ============================================================================
;; Shaders — written in the cl-webgpu/shader DSL
;;
;; Use cl-webgpu/shader/cl as the base package: it re-exports all of CL plus
;; the shader DSL (defstruct, defun, vec4, @, make, return, etc. are shadowed
;; or added).  The pattern mirrors golf/shaders/default-shader.lisp.
;; ============================================================================

(defpackage #:triangle-shaders
  (:use #:cl-webgpu/shader/cl)
  (:export #:vs-main #:fs-main))

(in-package #:triangle-shaders)

;;; Vertex output struct — clip position as a builtin, no varyings needed.
(defstruct (tri-vertex-output "VertexOutput")
  ((clip-position "clip_position") :vec4 :builtin position))

;;; Vertex entry point.
;;; The first scalar parameter of a vertex entry point is automatically
;;; annotated @builtin(vertex_index) by the WGSL printer.
(defun vs-main (vi)
  (declare (:int vi)
           (values tri-vertex-output))
  (let ((out (make tri-vertex-output))
        ;; Three hard-coded triangle corners indexed by vertex_index
        (x (if (= vi 0)  0.0 (if (= vi 1) -0.5  0.5)))
        (y (if (= vi 0)  0.5 (if (= vi 1) -0.5 -0.5))))
    (setf (@ out clip-position) (vec4 x y 0.0 1.0))
    (return out)))

;;; Fragment entry point — constant red.
;;; The vertex output struct flows through as the fragment input.
(defun fs-main (input)
  (declare (tri-vertex-output input)
           (values :vec4 :location 0))
  (return (vec4 1.0 0.0 0.0 1.0)))

;; ============================================================================
;; Main application package
;; ============================================================================

(defpackage #:triangle-wrapper-example
  (:use #:cl #:cl-webgpu/wrapper)
  (:import-from #:cl-webgpu #:load-wgpu-libraries)
  (:import-from #:cl-webgpu/glfw
                #:initialize
                #:terminate
                #:create-window
                #:destroy-window
                #:poll-events
                #:window-should-close-p))

(in-package #:triangle-wrapper-example)

;; Generate the combined WGSL source from the DSL definitions above.
;; Uncomment the format call to print the generated source for inspection.
(defparameter *shader-source*
  (cl-webgpu/shader:generate-shader :vertex 'triangle-shaders::vs-main
                                    :fragment 'triangle-shaders::fs-main))
;; (format t "~%--- Generated WGSL ---~%~a~%---~%" *shader-source*)

;; ============================================================================
;; Helpers
;; ============================================================================

(defun load-libraries ()
  (let* ((base (asdf:system-source-directory :cl-webgpu))
         (shim (namestring (merge-pathnames #P"shim/" base)))
         (wgpu (namestring (merge-pathnames #P"deps/wgpu-native/target/release/" base))))
    (cl-webgpu:load-wgpu-libraries :wgpu-path wgpu :shim-path shim)
    (cl-webgpu/glfw:load-glfw-library :path shim)))

(defun render-frame (device surface pipeline)
  "Acquire the current surface texture, draw the triangle, and present."
  (cffi:with-foreign-object (st '(:struct cl-webgpu:wgpu-surface-texture))
    (cl-webgpu:wgpu-surface-get-current-texture (handle surface) st)
    (let ((tex    (cffi:foreign-slot-value
                   st '(:struct cl-webgpu:wgpu-surface-texture) 'cl-webgpu:texture))
          (status (cffi:mem-ref
                   (cffi:foreign-slot-pointer
                    st '(:struct cl-webgpu:wgpu-surface-texture) 'cl-webgpu:status)
                   :uint32)))
      (when (and (not (cffi:null-pointer-p tex))
                 (or (= status 1) (= status 2)))   ; success-optimal / success-suboptimal
        (with-wgpu-struct (vdesc '(:struct cl-webgpu:wgpu-texture-view-descriptor))
          (let ((view (cl-webgpu:wgpu-texture-create-view tex vdesc)))
            (unwind-protect
                (with-gpu-command-encoder (encoder device)
                  (with-render-pass (pass encoder view
                                    :clear-r 0.1d0 :clear-g 0.1d0 :clear-b 0.3d0)
                    (cl-webgpu:wgpu-render-pass-encoder-set-pipeline
                     (handle pass) (handle pipeline))
                    (cl-webgpu:wgpu-render-pass-encoder-draw (handle pass) 3 1 0 0)
                    (let ((queue (cl-webgpu:wgpu-device-get-queue (handle device))))
                      (unwind-protect
                          (end-and-submit encoder pass
                                          (make-instance 'gpu-queue :handle queue)
                                          surface)
                        (cl-webgpu:wgpu-queue-release queue)))))
              (cl-webgpu:wgpu-texture-view-release view))))))))

;; ============================================================================
;; Entry point
;; ============================================================================

(defun run-triangle ()
  (load-libraries)
  #+sbcl (sb-int:set-floating-point-modes :traps nil)

  (cl-glfw3:initialize)
  (let ((window (cl-glfw3:create-window :width 640 :height 480
                                        :title "WebGPU Triangle (wrapper)"
                                        :client-api :no-api
                                        :resizable nil)))
    (unwind-protect
        (with-gpu-instance (inst)
          (with-gpu-adapter (adapter inst)
            (with-gpu-device (device inst adapter)
              (let* ((raw-surface (cl-webgpu/glfw:glfw-create-window-wgpu-surface
                                   (handle inst) window))
                     (surface (make-instance 'gpu-surface :handle raw-surface))
                     (fmt (get-surface-format surface adapter)))
                (unwind-protect
                    (progn
                      (configure-surface surface device fmt 640 480)
                      (with-gpu-shader-module (shader device *shader-source* :label "Triangle")
                        (with-gpu-render-pipeline (pipeline device
                                                   :vertex-module shader
                                                   :fragment-module shader
                                                   :surface-format fmt
                                                   :label "Triangle pipeline")
                          (format t "Rendering — close window to exit~%")
                          (loop until (cl-glfw3:window-should-close-p window)
                                do (cl-glfw3:poll-events)
                                   (render-frame device surface pipeline)
                                   (sleep 0.016)))))
                  (release surface))))))
      (cl-glfw3:destroy-window window)
      (cl-glfw3:terminate)
      (format t "Done.~%"))))

(run-triangle)
