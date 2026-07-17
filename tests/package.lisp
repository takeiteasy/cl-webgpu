;;;; tests/package.lisp
;;;; Test package for cl-webgpu/shader (the WGSL DSL)

(defpackage #:cl-webgpu/shader/tests
  (:use #:cl #:fiveam)
  (:export #:run-tests))

(in-package #:cl-webgpu/shader/tests)

(def-suite wgsl-tests
  :description "cl-webgpu/shader (WGSL DSL) test suite")

(defun run-tests ()
  "Run all wgsl DSL tests."
  (run! 'wgsl-tests))

;; DSL shader fixtures live in their own package (rather than
;; cl-webgpu/shader/tests itself) since defstruct/defun here shadow CL via
;; cl-webgpu/shader/cl -- keeping the FiveAM test forms in a plain :use #:cl
;; package avoids any shadowing surprises.
(defpackage #:cl-webgpu/shader/tests/fixtures
  (:use #:cl-webgpu/shader/cl))
