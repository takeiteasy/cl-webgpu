;;;; tests/fixtures.lisp
;;;;
;;;; Minimal DSL shader fixtures for wgsl-tests.lisp -- exercise the two DSL
;;;; regression cases below without pulling in a full shader project. Not
;;;; compiled on a GPU device; GENERATE-SHADER's output string is inspected
;;;; directly, so no wgpu-native/naga validation happens here.

(in-package #:cl-webgpu/shader/tests/fixtures)

(defstruct (test-vout "TestVertexOutput")
  ((clip-position "clip_position") :vec4 :builtin position)
  ((uv "uv") :vec2 :location 0))

;; Regression fixture: swizzle-component write, e.g. `uv.x = uv.x + 0.1`.
;; Before the WGSL-PRINTER.LISP fix, COLLECT-MUTABLE-BINDINGS never marked
;; UV mutable (printed `let uv = ...` instead of `var uv = ...`), and the
;; write itself printed as a broken `#<VARIABLE-READ ...>.x = ...` reference.
(defun swizzle-write-fs-main (in)
  (declare (test-vout in) (values :vec4 :location 0))
  (let ((uv (@ in uv)))
    (declare (:vec2 uv))
    (setf (.x uv) (+ (.x uv) 0.1))
    (return (vec4 uv 0.0 1.0))))

;; Regression fixture: 2-arg ATAN (GLSL-style atan(y, x)). Before the fix
;; this printed as WGSL's single-arg `atan(...)`, which naga rejects; WGSL's
;; real 2-arg builtin is separately named `atan2(y, x)`.
(defun atan2-fs-main (in)
  (declare (test-vout in) (values :vec4 :location 0))
  (let ((a (atan 1.0 2.0)))
    (declare (:float a))
    (return (vec4 a a a 1.0))))
