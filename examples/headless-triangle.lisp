;;;; examples/headless-triangle.lisp
;;;; WebGPU triangle rendered with cl-webgpu/wrapper, with no window at all:
;;;; draws one frame into a cl-webgpu/headless target and writes the result
;;;; to a PNG. Runs over SSH/CI with no display server (and, on macOS, no
;;;; screen-recording permission).

(ql:quickload '(:cl-webgpu :cl-webgpu/wrapper :cl-webgpu/headless))

(defpackage #:headless-triangle-example
  (:use #:cl #:cl-webgpu/wrapper)
  (:import-from #:cl-webgpu #:load-wgpu-libraries)
  (:import-from #:cl-webgpu/headless
                #:make-headless-target
                #:with-headless-frame
                #:readback-texture-png))

(in-package #:headless-triangle-example)

(defparameter *output-path* "/tmp/cl-webgpu-headless-triangle.png")

(defparameter *shader-source*
  "struct VertexOutput {
       @builtin(position) clip_position: vec4<f32>,
   }

   @vertex
   fn vs_main(@builtin(vertex_index) vi: u32) -> VertexOutput {
       var pos = array<vec2<f32>, 3>(
           vec2<f32>( 0.0,  0.5),
           vec2<f32>(-0.5, -0.5),
           vec2<f32>( 0.5, -0.5));
       var out: VertexOutput;
       out.clip_position = vec4<f32>(pos[vi], 0.0, 1.0);
       return out;
   }

   @fragment
   fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
       return vec4<f32>(1.0, 0.0, 0.0, 1.0);
   }")

(defun load-libraries ()
  (let* ((base (asdf:system-source-directory :cl-webgpu))
         (shim (namestring (merge-pathnames #P"shim/" base)))
         (wgpu (namestring (merge-pathnames #P"deps/wgpu-native/target/release/" base))))
    (cl-webgpu:load-wgpu-libraries :wgpu-path wgpu :shim-path shim)))

(defun run-headless-triangle ()
  (load-libraries)
  #+sbcl (sb-int:set-floating-point-modes :traps nil)
  (with-gpu* ((inst    (make-gpu-instance))
              (adapter (request-gpu-adapter inst))
              (device  (request-gpu-device inst adapter))
              (queue   (get-device-queue device))
              (shader  (make-shader-module device *shader-source* :label "Triangle")))
    (with-gpu* ((pipeline (make-render-pipeline device
                           :vertex-module shader
                           :fragment-module shader
                           :vertex-entry-point "vs_main"
                           :fragment-entry-point "fs_main"
                           ;; must match the headless target's format
                           :surface-format :rgba8-unorm
                           :label "Triangle pipeline"))
                (target   (make-headless-target device 640 480)))
      (with-headless-frame (pass device queue target
                           :clear-r 0.1d0 :clear-g 0.1d0 :clear-b 0.3d0 :clear-a 1.0d0)
        (set-pipeline pass pipeline)
        (draw pass 3))
      (readback-texture-png device queue target *output-path*)
      (format t "Wrote ~a~%" *output-path*))))

(run-headless-triangle)
