;;;; tests/wgsl-tests.lisp
;;;;
;;;; Regression tests for two cl-webgpu/shader DSL gaps found while porting
;;;; star's pixel-planets shaders (star ticket #121): swizzle-component
;;;; writes not marking their variable mutable, and no WGSL atan2 builtin.
;;;; Both were previously worked around downstream in star's
;;;; aux/pixel-planets/src/shaders/dsl-common.lisp rather than fixed here.

(in-package #:cl-webgpu/shader/tests)

(in-suite wgsl-tests)

(test swizzle-write-marks-variable-mutable
  "(setf (.x uv) ...) must declare `var uv`, not `let uv`, and must print
the write itself as `uv.x = ...`, not a broken object reference."
  (let ((wgsl (cl-webgpu/shader:generate-shader
               :fragment 'cl-webgpu/shader/tests/fixtures::swizzle-write-fs-main)))
    (is (search "var uv" wgsl) "expected `var uv` (mutable) declaration in:~%~a" wgsl)
    (is (not (search "let uv" wgsl)) "UV must not be declared immutable in:~%~a" wgsl)
    (is (search "uv.x = uv.x + 0.1;" wgsl) "expected in-place swizzle write in:~%~a" wgsl)
    (is (not (search "#<" wgsl)) "no raw Lisp object should leak into WGSL output:~%~a" wgsl)))

(test two-arg-atan-prints-as-atan2
  "A 2-arg (atan y x) call must print as WGSL's real two-argument builtin
`atan2(y, x)`, not the single-arg `atan(...)` WGSL/naga rejects."
  (let ((wgsl (cl-webgpu/shader:generate-shader
               :fragment 'cl-webgpu/shader/tests/fixtures::atan2-fs-main)))
    (is (search "atan2(1.0, 2.0)" wgsl) "expected atan2(...) call in:~%~a" wgsl)
    (is (not (search "atan(1.0, 2.0)" wgsl)) "must not emit invalid 2-arg atan(...) in:~%~a" wgsl)))
