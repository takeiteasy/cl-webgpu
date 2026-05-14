(defpackage #:cl-webgpu/shader
  (:use :cl)
  (:intern #:%shader-macro
           #:*package-environments*
           #:ensure-package-environment)
  (:export
   :layout
   :in
   :out
   :inout
   :generate-stage
   :generate-shader
   :compile-form
   :stage
   :*modified-function-hook*))

(defpackage #:cl-webgpu/shader/internal
  (:use :cl)
  (:shadow #:defun
           #:defconstant
           #:defmacro
           #:defstruct)
  (:import-from #:cl-webgpu/shader
                #:layout
                #:in
                #:out
                #:inout
                #:stage
                #:%shader-macro
                #:*package-environments*
                #:ensure-package-environment)
  (:export
   ;; shadowed from CL
   #:defun
   #:defmacro
   #:defconstant
   #:defstruct

   ;; ??
   #:generate-stage
   #:generate-shader
   #:shader-defun
   #:shader-interface
   #:shader-attribute
   #:shader-output
   #:shader-input
   #:shader-uniform
   #:shader-defconstant

   ;; glsl-side API
   #:layout
   #:in
   #:out
   #:inout
   #:interface
   #:attribute
   #:output
   #:@
   #:input
   #:uniform
   #:shared
   #:bind-interface
   #:stage

   ;; WGSL-native builtin names
   #:vertex-index
   #:instance-index
   #:frag-position
   #:front-facing
   #:sample-index
   #:sample-mask
   #:frag-depth
   #:sample-mask-out
   #:num-workgroups
   #:workgroup-id
   #:local-invocation-id
   #:global-invocation-id
   #:local-invocation-index

   ;; struct-based I/O
   #:make

   ;; built-in shader functions
   ;; many of these are just reexported from CL#: though meaning might
   ;; differ a bit

   #:<<
   #:>>
   #:^^
   #:radians
   #:degrees
   #:sin
   #:cos
   #:tan
   #:asin
   #:acos
   #:atan
   #:sinh
   #:cosh
   #:tanh
   #:asinh
   #:acosh
   #:atanh
   #:pow
   #:exp
   #:log
   #:exp2
   #:log2
   #:sqrt
   #:inverse-sqrt
   #:abs
   #:signum
   #:sign
   #:floor
   #:truncate
   #:trunc
   #:round
   #:round-even
   #:ceiling
   #:ceil
   #:fract
   #:mod
   #:modf
   #:min
   #:max
   #:clamp
   #:mix
   #:step
   #:smooth-step
   #:is-nan
   #:is-inf
   #:float-bits-to-int
   #:float-bits-to-uint
   #:int-bits-to-float
   #:uint-bits-to-float
   #:fma
   #:frexp
   #:ldexp
   ;; 8.4 floating-point pack and unpack functions
   #:pack-unorm-2x16
   #:pack-snorm-2x16
   #:pack-unorm-4x8
   #:pack-snorm-4x8
   #:unpack-unorm-2x16
   #:unpack-snorm-2x16
   #:unpack-unorm-4x8
   #:unpack-snorm-4x8
   #:pack-half-2x16
   #:unpack-half-2x16
   ;; 8.5 geometric functions
   #:length
   #:distance
   #:dot
   #:cross
   #:normalize
   #:face-forward
   #:reflect
   #:refract
   ;; 8.6 matrix functions
   #:matrix-comp-mult
   #:outer-product
   #:transpose
   #:determinant
   #:inverse
   ;; 8.7 vector relational functions
   #:less-than
   #:less-than-equal
   #:greater-than
   #:greater-than-equal
   #:equal
   #:not-equal
   #:any
   #:all
   ;; 8.8 integer functions
   #:uadd-carry
   #:usub-borrow
   #:umul-extended
   #:imul-extended
   #:bitfield-extract
   #:bitfield-insert
   #:bitfield-reverse
   #:bit-count
   #:find-lsb
   #:find-msb
   ;; 8.9 Texture Functions
   #:texture-size
   #:texture-query-lod
   #:texture-query-levels
   #:texture-samples
   #:texture
   #:texture-proj
   #:texture-lod
   #:texture-offset
   #:texel-fetch
   #:texel-fetch-offset
   #:texture-proj-offset
   #:texture-lod-offset
   #:texture-proj-lod
   #:texture-proj-lod-offset
   #:texture-grad
   #:texture-grad-offset
   #:texture-proj-grad
   #:texture-proj-grad-offset
   ;; 8.9.3 texture gather functions
   #:texture-gather
   #:texture-gather-offset
   #:texture-gather-offsets
   ;; 8.11 atomic memory functions
   #:atomic-add
   #:atomic-min
   #:atomic-max
   #:atomic-and
   #:atomic-or
   #:atomic-xor
   #:atomic-exchange
   #:atomic-comp-swap
   ;; 8.13 fragment processing functions
   ;; 8.13.1 derivative functions
   #:dfdx
   #:dfdy
   #:dfdx-fine
   #:dfdy-fine
   #:dfdx-coarse
   #:dfdy-coarse
   #:fwidth
   #:fwidth-fine
   #:fwidth-coarse
   ;; 8.13.2 interpolation functions
   ;; these specify float/vec2/vec3/vec4 explicitly instead of gentype?
   #:interpolate-at-centroid
   #:interpolate-at-sample
   #:interpolate-at-centroid
   ;; 8.16 shader invocation control functions
   #:barrier
   ;; 8.17 Shader memory control functions
   #:memory-barrier
   #:memory-barrier-atomic-counter
   #:memory-barrier-buffer
   #:memory-barrier-shared
   #:memory-barrier-image
   #:group-memory-barrier
   ;; 8.19 Shader Invocation Group Functions
   #:any-invocation
   #:all-invocations
   #:all-invocations-equal

   ;; vector/matrix constructors
   #:int
   #:uint
   #:bool
   #:float
   #:bvec2
   #:bvec3
   #:bvec4
   #:ivec2
   #:ivec3
   #:ivec4
   #:uvec2
   #:uvec3
   #:uvec4
   #:vec2
   #:vec3
   #:vec4
   #:mat2
   #:mat2x3
   #:mat2x4
   #:mat3x2
   #:mat3
   #:mat3x4
   #:mat4x2
   #:mat4x3
   #:mat4
   ;; misc
   #:discard
   ;; WGSL-native texture sampling
   #:texture-sample
   ;; uint loop
   #:dotimes/u
   ))

;;; package intended to be :USEd by shader code in place of :cl
;;; exports all symbols from cl-webgpu/shader/internal, and any CL symbols not
;;; shadowed by it
(defpackage #:cl-webgpu/shader/cl
  (:use #:cl #:cl-webgpu/shader/internal)
  (:shadowing-import-from #:cl-webgpu/shader/internal #:defun #:defconstant
                          #:defmacro #:defstruct)
  #. (cons :export
           (flet ((externals (x)
                    (let ((a))
                      (do-external-symbols (s x)
                        (push s a))
                      a)))
             (append (externals '#:cl-webgpu/shader/internal)
                     (loop for s in (externals '#:cl)
                           unless
                           (eq :external
                               (nth-value 1 (find-symbol (symbol-name s)
                                                         '#:cl-webgpu/shader/internal)))
                           collect s)))))
