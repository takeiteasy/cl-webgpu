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

(defun render-frame (device queue surface pipeline)
  "Acquire the current surface texture, draw the triangle, and present.
ACQUIRE-FRAME-TEXTURE-VIEW returns NIL when the surface has no frame ready
this call (e.g. a suboptimal/outdated texture) -- callers just skip the frame
and try again next iteration; a resizable window would also reconfigure the
surface here (see cl-webgpu/wrapper:get-current-surface-texture for that)."
  (let ((view (acquire-frame-texture-view surface)))
    (when view
      (unwind-protect
          (with-gpu-command-encoder (encoder device)
            (with-render-pass (pass encoder view
                              :clear-r 0.1d0 :clear-g 0.1d0 :clear-b 0.3d0)
              (set-pipeline pass pipeline)
              (draw pass 3)
              (end-and-submit encoder pass queue surface)))
        (release view)))))

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
        (with-gpu* ((inst    (make-gpu-instance))
                    (adapter (request-gpu-adapter inst))
                    (device  (request-gpu-device inst adapter))
                    (queue   (get-device-queue device))
                    (surface (make-instance 'gpu-surface
                                            :handle (cl-webgpu/glfw:glfw-create-window-wgpu-surface
                                                     (handle inst) window)))
                    (shader  (make-shader-module device *shader-source* :label "Triangle")))
          (let ((fmt (get-surface-format surface adapter)))
            (configure-surface surface device fmt 640 480)
            (with-gpu* ((pipeline (make-render-pipeline device
                                   :vertex-module shader
                                   :fragment-module shader
                                   :vertex-entry-point "vs_main"
                                   :fragment-entry-point "fs_main"
                                   :surface-format fmt
                                   :label "Triangle pipeline")))
              (format t "Rendering — close window to exit~%")
              (loop until (cl-glfw3:window-should-close-p window)
                    do (cl-glfw3:poll-events)
                       (render-frame device queue surface pipeline)
                       (sleep 0.016)))))
      (cl-glfw3:destroy-window window)
      (cl-glfw3:terminate)
      (format t "Done.~%"))))

(run-triangle)
