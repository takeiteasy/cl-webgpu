;;;; tests/wrapper-package.lisp
;;;; Test package for cl-webgpu/wrapper (the CLOS wrapper layer)

(defpackage #:cl-webgpu/wrapper/tests
  (:use #:cl #:fiveam)
  (:export #:run-tests))

(in-package #:cl-webgpu/wrapper/tests)

(def-suite wrapper-tests
  :description "cl-webgpu/wrapper smoke tests -- require a real GPU adapter")

(defun %load-wgpu-libraries ()
  "Load the native wgpu-native + shim libraries from their build locations
relative to the cl-webgpu system, same layout used by examples/."
  (let* ((base (asdf:system-source-directory :cl-webgpu))
         (shim (namestring (merge-pathnames #P"shim/" base)))
         (wgpu (namestring (merge-pathnames #P"deps/wgpu-native/target/release/" base))))
    (cl-webgpu:load-wgpu-libraries :wgpu-path wgpu :shim-path shim)))

(defun run-tests ()
  "Run all wrapper smoke tests. Requires a real GPU adapter (Metal on macOS).
Disables SBCL's floating-point traps first -- wgpu-native's Metal backend
does float math that signals SIGFPE under SBCL's default trap set, same as
examples/triangle.lisp et al. must do before touching the GPU."
  #+sbcl (sb-int:set-floating-point-modes :traps nil)
  (%load-wgpu-libraries)
  (run! 'wrapper-tests))
