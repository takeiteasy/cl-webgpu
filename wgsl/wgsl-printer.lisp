(in-package #:cl-webgpu/shader)

;;; WGSL (WebGPU Shading Language) backend for cl-webgpu/shader

(defvar *emit-ugly-preamble* nil
  "When true, emit a standard uniform preamble (group 0) in generated WGSL.
When false (default), omit it so the shader defines its own group 0 layout.")

;; Reverse lookup: WGSL type constructor names (for detecting type constructors in expressions)
(defparameter *wgsl-type-constructor-names*
  (let ((ht (make-hash-table :test 'equal)))
    (dolist (name '("vec2" "vec3" "vec4"
                    "ivec2" "ivec3" "ivec4"
                    "uvec2" "uvec3" "uvec4"
                    "bvec2" "bvec3" "bvec4"
                    "mat2" "mat3" "mat4"
                    "mat2x2" "mat2x3" "mat2x4"
                    "mat3x2" "mat3x3" "mat3x4"
                    "mat4x2" "mat4x3" "mat4x4"
                    "float" "int" "uint" "bool"))
      (setf (gethash name ht) t))
    ht))

;; DSL function name mapping
(defparameter *wgsl-function-map*
  (alexandria:plist-hash-table
   '(dfdx "dpdx"
     dfdy "dpdy"
     dfdx-fine "dpdxFine"
     dfdy-fine "dpdyFine"
     dfdx-coarse "dpdxCoarse"
     dfdy-coarse "dpdyCoarse"
     texture-lod "textureSampleLevel"
     texel-fetch "textureLoad"
     inverse-sqrt "inverseSqrt"
     smooth-step "smoothstep"
     fract "fract"
     mix "mix"
     clamp "clamp"
     normalize "normalize"
     dot "dot"
     cross "cross"
     length "length"
     distance "distance"
     abs "abs"
     min "min"
     max "max"
     pow "pow"
     sqrt "sqrt"
     sin "sin"
     cos "cos"
     tan "tan"
     asin "asin"
     acos "acos"
     atan "atan"
     sinh "sinh"
     cosh "cosh"
     tanh "tanh"
     exp "exp"
     exp2 "exp2"
     log "log"
     log2 "log2"
     sign "sign"
     floor "floor"
     ceil "ceil"
     round "round"
     step "step"
     reflect "reflect"
     refract "refract"
     face-forward "faceForward"
     fwidth "fwidth"
     transpose "transpose"
     determinant "determinant"
     inverse "inverse"
     outer-product "outerProduct"
     any "any"
     all "all"
     select "select"
     ;; Texture functions
     texture "textureSample"
     texture-sample "textureSample"
     texture-proj "textureSample"
     texture-size "textureDimensions"
     ;; Atomic functions
     atomic-add "atomicAdd"
     atomic-min "atomicMin"
     atomic-max "atomicMax"
     atomic-and "atomicAnd"
     atomic-or "atomicOr"
     atomic-xor "atomicXor"
     atomic-exchange "atomicExchange"
     atomic-comp-swap "atomicCompareExchangeWeak"
     ;; Barrier
     barrier "workgroupBarrier")))

(defun wgsl-type-name (type-name)
  "Convert a type keyword to WGSL type name string."
  (let ((binding (get-type-binding type-name)))
    (if binding
        (or (target-name binding) (string-downcase (symbol-name type-name)))
        (string-downcase (symbol-name type-name)))))

(defun wgsl-translate-type (type)
  "Translate a type object to a WGSL type string."
  (typecase type
    (concrete-type (wgsl-type-name (name type)))
    (array-type
     (let ((base (wgsl-translate-type
                  (base-type (or (and (boundp '*binding-types*)
                                      (gethash type *binding-types*))
                                 (value-type type)))))
           (size (array-size type)))
       (if (numberp size)
           (format nil "array<~a, ~d>" base size)
           (format nil "array<~a>" base))))
    (struct-type
     (or (target-name type) (%translate-name (name type))))
    (t (translate-type type))))


;;; WGSL Context for code generation

(defclass wgsl-shader-context ()
  ((stage :initarg :stage :accessor wgsl-stage)
   (inputs :initform nil :accessor wgsl-inputs)
   (outputs :initform nil :accessor wgsl-outputs)
   (uniforms :initform nil :accessor wgsl-uniforms)
   (binding-index :initform 0 :accessor wgsl-binding-index)))

(defvar *wgsl-context* nil)

;; Rename table: binding object -> string name (for entry point params)
(defvar *wgsl-rename-table* nil)

(defun collect-wgsl-bindings (objects stage)
  "Collect input/output/uniform/buffer bindings for WGSL struct generation.
Returns four values: inputs, outputs, uniforms, buffers.
The :buffer qualifier (var<storage, ACCESS>) is stored as the bare keyword :buffer;
access mode is controlled separately via :access in the :layout plist and is
resolved by print-wgsl-user-buffers."
  (let ((inputs nil)
        (outputs nil)
        (uniforms nil)
        (buffers nil))
    (loop for obj in objects
          when (typep obj 'interface-binding)
            do (let* ((sb (stage-binding obj))
                      (iq (interface-qualifier sb))
                      (iq-key (if (consp iq) (car iq) iq)))
                 (case iq-key
                   (:in (push obj inputs))
                   (:out (push obj outputs))
                   (:uniform (push obj uniforms))
                   (:buffer (push obj buffers)))))
    (values (nreverse inputs)
            (nreverse outputs)
            (nreverse uniforms)
            (nreverse buffers))))

;;; Ugly standard preamble — the fixed group(0) uniform layout
;;; Custom shaders MUST declare this because ugly always binds its
;;; standard uniform buffer at group(0).

(defun print-wgsl-ugly-preamble (stream &optional (texture-type "texture_2d<f32>"))
  "Emit the ugly standard uniform structs and bindings at @group(0).
TEXTURE-TYPE overrides the type of the t_diffuse binding (default: texture_2d<f32>)."
  (format stream "// ugly standard uniform layout (group 0)
struct LightData {
    position: vec4<f32>,
    ambient: vec4<f32>,
    diffuse: vec4<f32>,
    specular: vec4<f32>,
    spot_direction: vec3<f32>,
    spot_cutoff: f32,
    spot_exponent: f32,
    enabled: u32,
    _padding: vec2<f32>,
}

struct MaterialData {
    ambient: vec4<f32>,
    diffuse: vec4<f32>,
    specular: vec4<f32>,
    shininess: f32,
    use_vertex_color: u32,
    _padding: vec2<f32>,
}

struct Uniforms {
    projection: mat4x4<f32>,
    texture_enabled: u32,
    lighting_enabled: u32,
    fog_enabled: u32,
    shade_model: u32,
    fog_color: vec4<f32>,
    fog_mode: u32,
    fog_density: f32,
    fog_start: f32,
    fog_end: f32,
    global_ambient: vec4<f32>,
    material: MaterialData,
    lights: array<LightData, 4>,
    texture_layer: u32,
    normalize_enabled: u32,
    alpha_test_enabled: u32,
    alpha_func: u32,
    alpha_ref: f32,
    object_id: u32,
    _pad2: u32,
    _pad3: u32,
}

@group(0) @binding(0)
var<uniform> uniforms: Uniforms;

@group(0) @binding(1)
var t_diffuse: ~a;

@group(0) @binding(2)
var s_diffuse: sampler;

" texture-type))

;;; WGSL Input/Output Struct Generation

(defun print-wgsl-vertex-input-struct (inputs stream)
  "Print the WGSL input struct for vertex shader."
  (format stream "struct VertexInput {~%")
  (let ((index 0))
    (loop for input in inputs
          for sb = (stage-binding input)
          for type = (value-type sb)
          for lq = (layout-qualifier sb)
          for location = (or (getf lq :location) index)
          do (format stream "    @location(~d) ~a: ~a,~%"
                     location
                     (translate-name input)
                     (wgsl-type-name (name type)))
             (incf index)))
  (format stream "}~%~%"))

(defun print-wgsl-vertex-output-struct (outputs stream)
  "Print the WGSL output struct for vertex shader."
  (format stream "struct VertexOutput {~%")
  (format stream "    @builtin(position) position: vec4<f32>,~%")
  (let ((locn-index 0))
    (loop for output in outputs
          for sb = (stage-binding output)
          do (cond
               ((or (interface-block sb) (typep (binding sb) 'bindings))
                (let ((bindings (bindings (or (interface-block sb) (binding sb)))))
                  (loop for b in bindings
                        do (format stream "    @location(~d) ~a: ~a,~%"
                                   locn-index
                                   (translate-name b)
                                   (wgsl-type-name (name (value-type b))))
                           (incf locn-index))))
               (t
                (format stream "    @location(~d) ~a: ~a,~%"
                        locn-index
                        (translate-name output)
                        (wgsl-type-name (name (value-type sb))))
                (incf locn-index)))))
  (format stream "}~%~%"))

(defun print-wgsl-fragment-input-struct (inputs stream)
  "Print the WGSL input struct for fragment shader."
  (format stream "struct FragmentInput {~%")
  (format stream "    @builtin(position) position: vec4<f32>,~%")
  (let ((locn-index 0))
    (loop for input in inputs
          for sb = (stage-binding input)
          do (cond
               ((or (interface-block sb) (typep (binding sb) 'bindings))
                (let ((bindings (bindings (or (interface-block sb) (binding sb)))))
                  (loop for b in bindings
                        do (format stream "    @location(~d) ~a: ~a,~%"
                                   locn-index
                                   (translate-name b)
                                   (wgsl-type-name (name (value-type b))))
                           (incf locn-index))))
               (t
                (format stream "    @location(~d) ~a: ~a,~%"
                        locn-index
                        (translate-name input)
                        (wgsl-type-name (name (value-type sb))))
                (incf locn-index)))))
  (format stream "}~%~%"))

(defun print-wgsl-fragment-output-struct (outputs stream)
  "Print the WGSL output struct for fragment shader."
  (format stream "struct FragmentOutput {~%")
  (let ((color-index 0))
    (loop for output in outputs
          for sb = (stage-binding output)
          for type = (value-type sb)
          do (format stream "    @location(~d) ~a: ~a,~%"
                     color-index
                     (translate-name output)
                     (wgsl-type-name (name type)))
             (incf color-index)))
  (format stream "}~%~%"))

;;; User Uniform Generation (emits at @group(1))

(defun is-wgsl-sampler-type-name (type-name)
  "Return T if TYPE-NAME is a sampler type."
  (member type-name '(:sampler :sampler-2d :sampler-3d :sampler-cube :sampler-2d-array
                      :isampler-2d :isampler-3d :isampler-cube :isampler-2d-array
                      :usampler-2d :usampler-3d :usampler-cube :usampler-2d-array
                      :sampler-2d-shadow :sampler-cube-shadow :sampler-2d-array-shadow)))

(defun print-wgsl-user-uniforms (uniforms stream)
  "Print user uniform buffer at @group(1) and resource bindings."
  ;; Separate uniforms with explicit group/binding from those without
  (let ((explicit-uniforms nil)
        (implicit-uniforms nil))
    (loop for u in uniforms
          for sb = (stage-binding u)
          for lq = (layout-qualifier sb)
          for has-explicit = (and (getf lq :group) (getf lq :binding))
          do (if has-explicit
                 (push u explicit-uniforms)
                 (push u implicit-uniforms)))
    (setf explicit-uniforms (nreverse explicit-uniforms))
    (setf implicit-uniforms (nreverse implicit-uniforms))

    ;; Emit explicitly-bound uniforms individually
    (loop for u in explicit-uniforms
          for sb = (stage-binding u)
          for lq = (layout-qualifier sb)
          for type = (value-type sb)
          for group = (getf lq :group)
          for binding = (getf lq :binding)
          for type-name = (name type)
          for is-resource = (or (is-wgsl-sampler-type-name type-name)
                                (eq type-name :sampler))
          do (format stream "@group(~d) @binding(~d) ~a ~a: ~a;~%~%"
                     group binding
                     (if is-resource "var" "var<uniform>")
                     (translate-name u)
                     (wgsl-translate-type type)))

    ;; Implicit uniforms: group into UserUniforms struct at @group(1) @binding(0)
    (let ((scalar-uniforms (loop for u in implicit-uniforms
                                 for sb = (stage-binding u)
                                 for type = (value-type sb)
                                 unless (is-wgsl-sampler-type-name (name type))
                                   collect u)))
      (when scalar-uniforms
        (format stream "struct UserUniforms {~%")
        (loop for u in scalar-uniforms
              for sb = (stage-binding u)
              for type = (value-type sb)
              do (format stream "    ~a: ~a,~%"
                         (translate-name u)
                         (wgsl-type-name (name type))))
        (format stream "};~%~%")
        (format stream "@group(1) @binding(0) var<uniform> user_uniforms: UserUniforms;~%~%")))

    ;; Group 1: Textures and samplers (bindings 1+)
    (let ((binding-idx 1))
      (loop for u in implicit-uniforms
            for sb = (stage-binding u)
            for type = (value-type sb)
            for type-name = (name type)
            when (is-wgsl-sampler-type-name type-name)
              do (let ((tex-type (case type-name
                                   ((:sampler-2d :isampler-2d :usampler-2d) "texture_2d<f32>")
                                   ((:sampler-3d :isampler-3d :usampler-3d) "texture_3d<f32>")
                                   ((:sampler-cube :isampler-cube :usampler-cube) "texture_cube<f32>")
                                   ((:sampler-2d-array :isampler-2d-array :usampler-2d-array) "texture_2d_array<f32>")
                                   (:sampler-2d-shadow "texture_depth_2d")
                                   (t "texture_2d<f32>"))))
                   (format stream "@group(1) @binding(~d) var ~a_texture: ~a;~%"
                           binding-idx (translate-name u) tex-type)
                   (incf binding-idx)
                   (format stream "@group(1) @binding(~d) var ~a_sampler: sampler;~%"
                           binding-idx (translate-name u))
                   (incf binding-idx)))
      (when (> binding-idx 1)
        (format stream "~%")))))

(defun %buffer-access-mode-string (access)
  "Resolve an :access layout keyword to the WGSL storage access-mode string.
Valid values (from the :layout plist's :access key):
  nil / :read-write → \"read_write\"  (default; preserves existing behaviour)
  t                 → \"read_write\"  (alias matching the :buffer t idiom)
  :read             → \"read\"
  :write            → signals an error — var<storage, write> is invalid WGSL.
  anything else     → signals an error naming the bad value."
  (case access
    ((nil :read-write t) "read_write")
    (:read  "read")
    (:write (error "~@<DSL error: :access :write is not a valid WGSL storage ~
access mode.  WGSL storage buffers support only :read and :read-write.~:@>"))
    (t      (error "~@<DSL error: unknown storage access mode ~s.  ~
Valid values are :read and :read-write (default).~:@>" access))))

(defun print-wgsl-user-buffers (buffers stream)
  "Emit struct definitions and @group(N) @binding(N) var<storage, ACCESS>
lines for storage buffer blocks.

The struct definition is emitted here because the general struct-emission loop
in generate-wgsl only handles struct-type objects, not interface-type blocks.
Only buffers with explicit :group/:binding layout qualifiers are emitted.

Access mode is controlled by the :access key in the :layout plist:
  (:buffer t :layout (:group N :binding N))            → var<storage, read_write>  (default)
  (:buffer t :layout (:group N :binding N :access :read))      → var<storage, read>
  (:buffer t :layout (:group N :binding N :access :read-write)) → var<storage, read_write>
  :access :write is rejected at DSL compile time — it is not valid WGSL.

Two binding patterns are supported:
  Named — (interface my-block (:buffer inst-name :layout (:group N :binding N)) ...)
    inst-name is visible as an aggregate in shader code.
    interface-block is nil; value-type returns the interface-type.
  T-binding — (interface my-block (:buffer t :layout (:group N :binding N)) ...)
    Slots are directly visible as variables; interface-block holds the block type."
  (let ((seen-blocks (make-hash-table)))
    (loop for b in buffers
          for sb = (stage-binding b)
          for lq = (layout-qualifier sb)
          for group = (getf lq :group)
          for binding-idx = (getf lq :binding)
          for access-mode = (%buffer-access-mode-string (getf lq :access))
          ;; For T-binding, interface-block is the block type (slots bound individually).
          ;; For named binding, interface-block is nil but value-type = the interface-type.
          for block-type = (or (interface-block sb) (value-type sb))
          when (and group binding-idx block-type (name block-type))
            do (let ((block-name (name block-type)))
                 (unless (gethash block-name seen-blocks)
                   (setf (gethash block-name seen-blocks) t)
                   ;; Emit the struct definition (not emitted by the general struct loop)
                   (print-wgsl-struct block-type stream)
                   ;; Emit the var<storage, ACCESS> binding.
                   ;; For T-bindings, use the block type name as the instance name
                   ;; (fields accessed as block_name.field in generated code).
                   ;; For named bindings, use translate-name on b (the instance name).
                   (let ((inst-name (if (interface-block sb)
                                        (translate-name block-type)
                                        (translate-name b))))
                     (format stream
                             "@group(~d) @binding(~d) var<storage, ~a> ~a: ~a;~%~%"
                             group binding-idx
                             access-mode
                             inst-name
                             (wgsl-translate-type block-type))))))))

;;; WGSL builtin name mapping for @builtin annotations

(defparameter *wgsl-builtin-names*
  '((position . "position")
    (vertex-index . "vertex_index")
    (instance-index . "instance_index")
    (front-facing . "front_facing")
    (frag-depth . "frag_depth")
    (sample-index . "sample_index")
    (sample-mask . "sample_mask")
    (global-invocation-id . "global_invocation_id")
    (local-invocation-id . "local_invocation_id")
    (workgroup-id . "workgroup_id")
    (num-workgroups . "num_workgroups")
    (local-invocation-index . "local_invocation_index")))

(defun wgsl-builtin-string (sym)
  "Convert a builtin symbol to its WGSL @builtin string."
  (or (cdr (assoc sym *wgsl-builtin-names*))
      (string-downcase (symbol-name sym))))

(defun struct-has-annotations-p (struct)
  "Return T if any slot in STRUCT has :location or :builtin annotations."
  (some (lambda (b) (typep b 'annotated-binding))
        (bindings struct)))

;;; User-defined struct printing

(defun print-wgsl-struct (struct stream)
  "Print a struct type definition in WGSL."
  (format stream "struct ~a {~%" (or (target-name struct)
                                       (%translate-name (name struct))))
  (loop for b in (bindings struct)
        do (cond
             ((and (typep b 'annotated-binding) (binding-builtin b))
              (format stream "    @builtin(~a) ~a: ~a,~%"
                      (wgsl-builtin-string (binding-builtin b))
                      (translate-name b)
                      (wgsl-translate-type (value-type b))))
             ((and (typep b 'annotated-binding) (binding-location b))
              (format stream "    @location(~d) ~a: ~a,~%"
                      (binding-location b)
                      (translate-name b)
                      (wgsl-translate-type (value-type b))))
             (t
              (format stream "    ~a: ~a,~%"
                      (translate-name b)
                      (wgsl-translate-type (value-type b))))))
  (format stream "}~%~%"))

;;; Main WGSL Output Generation

(defun main-function-has-struct-io-p (objects)
  "Check if the main function in OBJECTS uses explicit struct I/O."
  (let ((main (find-if (lambda (o)
                         (and (typep o 'global-function)
                              (eq o *print-as-main*)))
                       objects)))
    (when main
      (function-has-struct-io-p main))))

(defun generate-wgsl (objects inferred-types)
  "Generate WGSL shader source from compiled shader objects."
  (let* ((*wgsl-name-mode* t)
         (stage *current-shader-stage*)
         (explicit-struct-io (main-function-has-struct-io-p objects)))
    (multiple-value-bind (inputs outputs uniforms buffers)
        (collect-wgsl-bindings objects stage)
      (let ((*wgsl-context* (make-instance 'wgsl-shader-context
                                           :stage stage)))
        (setf (wgsl-inputs *wgsl-context*) inputs
              (wgsl-outputs *wgsl-context*) outputs
              (wgsl-uniforms *wgsl-context*) uniforms)

        (with-output-to-string (*standard-output*)
          ;; Emit ugly's standard uniform preamble (group 0)
          (when *emit-ugly-preamble*
            (print-wgsl-ugly-preamble *standard-output*))

          ;; User-defined structs (includes annotated ones)
          ;; Skip internal structs when preamble is active (preamble provides them)
          (loop for object in objects
                when (and (typep object 'struct-type)
                          (not (and *emit-ugly-preamble* (internal object))))
                  do (print-wgsl-struct object *standard-output*))

          ;; User uniforms at group(1)
          ;; Filter out internal uniforms when preamble is active
          (let ((visible-uniforms
                  (if *emit-ugly-preamble*
                      (remove-if (lambda (u) (internal u)) uniforms)
                      uniforms)))
            (when visible-uniforms
              (print-wgsl-user-uniforms visible-uniforms *standard-output*)))

          ;; Storage buffers (var<storage, read_write>)
          (when buffers
            (print-wgsl-user-buffers buffers *standard-output*))

          ;; Auto-generated input/output structs — only when no explicit struct I/O
          (unless explicit-struct-io
            (case stage
              (:vertex
               (when inputs
                 (print-wgsl-vertex-input-struct inputs *standard-output*))
               (print-wgsl-vertex-output-struct outputs *standard-output*))
              (:fragment
               (let ((frag-inputs (loop for obj in objects
                                        when (typep obj 'interface-binding)
                                          when (let* ((sb (stage-binding obj))
                                                      (iq (interface-qualifier sb)))
                                                 (eq (if (consp iq) (car iq) iq) :in))
                                            collect obj)))
                 (when frag-inputs
                   (print-wgsl-fragment-input-struct frag-inputs *standard-output*)))
               (when outputs
                 (print-wgsl-fragment-output-struct outputs *standard-output*)))))

          ;; Helper functions first, then main
          (loop for object in objects
                when (typep object 'global-function)
                  do (let ((overloads (gethash object inferred-types)))
                       (assert overloads)
                       (loop for overload in overloads
                             for *binding-types* = (gethash overload
                                                           (final-binding-type-cache object))
                             do (assert *binding-types*)
                                (print-wgsl-function object stage *standard-output*)))))))))

;;; Function printer

(defun function-has-struct-io-p (func)
  "Check if a function uses explicit struct-based I/O.
Returns (values has-struct-io return-struct-type arg-struct-types)."
  (let* ((ret-type (or (and (boundp '*binding-types*)
                            (gethash :return *binding-types*))
                       (declared-type func)))
         (ret-struct (and (typep ret-type 'struct-type)
                          (struct-has-annotations-p ret-type)
                          ret-type))
         (arg-structs (loop for b in (bindings func)
                            for bt = (or (and (boundp '*binding-types*)
                                              (gethash b *binding-types*))
                                         (declared-type b))
                            when (and (typep bt 'struct-type)
                                      (struct-has-annotations-p bt))
                              collect (cons b bt))))
    (values (or ret-struct arg-structs) ret-struct arg-structs)))

(defun print-wgsl-function (func stage stream)
  "Print a WGSL function definition."
  (let* ((name (translate-name func))
         (is-main (string= name "main"))
         ;; ugly convention: vs_main / fs_main
         (entry-name (if is-main
                         (case stage
                           (:vertex "vs_main")
                           (:fragment "fs_main")
                           (:compute "cs_main")
                           (t "main"))
                         name)))
    (multiple-value-bind (has-struct-io ret-struct arg-structs)
        (when is-main (function-has-struct-io-p func))
      (cond
        ;; New-style: main with explicit struct I/O
        ((and is-main has-struct-io)
         (format stream "~%@~a~%"
                 (case stage
                   (:vertex "vertex")
                   (:fragment "fragment")
                   (:compute "compute")
                   (t "vertex")))
         (let* ((ret-str (cond
                           (ret-struct
                            (wgsl-translate-type ret-struct))
                           ((return-location func)
                            (let ((ret-type (or (and (boundp '*binding-types*)
                                                     (gethash :return *binding-types*))
                                                (declared-type func))))
                              (format nil "@location(~d) ~a"
                                      (return-location func)
                                      (wgsl-translate-type ret-type))))
                           (t
                            (let ((ret-type (or (and (boundp '*binding-types*)
                                                     (gethash :return *binding-types*))
                                                (declared-type func))))
                              (wgsl-translate-type ret-type)))))
                ;; Rename entry point parameter to "in"
                (*wgsl-rename-table* (let ((ht (make-hash-table)))
                                       (when arg-structs
                                         (setf (gethash (caar arg-structs) ht) "in"))
                                       ht)))
           ;; Non-struct scalar parameters (e.g. @builtin(vertex_index) i: u32)
           ;; These are entry-function params that aren't struct-typed.
           (let* ((non-struct-params
                    (loop for b in (bindings func)
                          for bt = (or (and (boundp '*binding-types*)
                                            (gethash b *binding-types*))
                                       (declared-type b))
                          unless (and (typep bt 'struct-type)
                                      (struct-has-annotations-p bt))
                            collect (cons b bt)))
                  ;; Map scalar entry params to stage builtins in order
                  (stage-builtins
                    (case stage
                      (:vertex '("vertex_index" "instance_index"))
                      (:fragment '("front_facing" "sample_index"))
                      (t nil)))
                  (builtin-param-strs
                    (loop for (b . bt) in non-struct-params
                          for builtin in stage-builtins
                          when builtin
                            ;; vertex_index/instance_index/sample_index are
                            ;; unconditionally u32 in WGSL regardless of how
                            ;; the user declared the Lisp parameter -- using
                            ;; the declared type here (e.g. :int -> i32) is
                            ;; rejected by wgpu-native with a fatal panic,
                            ;; not just a validation error.
                            collect (format nil "@builtin(~a) ~a: ~a"
                                            builtin
                                            (translate-name b)
                                            (if (member builtin '("vertex_index"
                                                                   "instance_index"
                                                                   "sample_index")
                                                        :test #'string=)
                                                "u32"
                                                (wgsl-translate-type bt))))))
             (format stream "fn ~a(~{~a~^, ~}) -> ~a {~%"
                     entry-name
                     (append builtin-param-strs
                             (loop for (b . st) in arg-structs
                                   collect (format nil "~a: ~a"
                                                   (or (gethash b *wgsl-rename-table*)
                                                       (translate-name b))
                                                   (wgsl-translate-type st))))
                     ret-str))
           (print-wgsl-function-body func stage stream)
           (format stream "}~%")))
        ;; Old-style: main without struct I/O
        (is-main
         (format stream "~%@~a~%"
                 (case stage
                   (:vertex "vertex")
                   (:fragment "fragment")
                   (:compute "compute")
                   (t "vertex")))
         (format stream "fn ~a(input: ~a) -> ~a {~%"
                 entry-name
                 (case stage
                   (:vertex "VertexInput")
                   (:fragment "FragmentInput")
                   (t "VertexInput"))
                 (case stage
                   (:vertex "VertexOutput")
                   (:fragment "FragmentOutput")
                   (t "VertexOutput")))
         (format stream "    var output: ~a;~%"
                 (case stage
                   (:vertex "VertexOutput")
                   (:fragment "FragmentOutput")
                   (t "VertexOutput")))
         (print-wgsl-function-body func stage stream)
         (format stream "    return output;~%")
         (format stream "}~%"))
        ;; Regular helper function
        (t
         (let ((fn-bindings (bindings func))
               (ret-type (or (gethash :return *binding-types*)
                             (value-type func))))
           (if (> (length fn-bindings) 1)
               ;; Multi-line signature for 2+ args
               (progn
                 (format stream "~%fn ~a(~%" entry-name)
                 (loop for b in fn-bindings
                       do (format stream "    ~a: ~a,~%"
                                   (translate-name b)
                                   (wgsl-translate-type
                                    (or (and (boundp '*binding-types*)
                                             (gethash b *binding-types*))
                                        (value-type b)))))
                 (format stream ") -> ~a {~%" (wgsl-translate-type ret-type)))
               ;; Single-line signature for 0-1 args
               (format stream "~%fn ~a(~{~a~^, ~}) -> ~a {~%"
                       entry-name
                       (loop for b in fn-bindings
                             collect (format nil "~a: ~a"
                                             (translate-name b)
                                             (wgsl-translate-type
                                              (or (and (boundp '*binding-types*)
                                                       (gethash b *binding-types*))
                                                  (value-type b)))))
                       (wgsl-translate-type ret-type)))
           (print-wgsl-function-body func stage stream)
           (format stream "}~%")))))))

;;; Binding mutability check — must be declared before print-wgsl-function-body uses it
(defvar *wgsl-mutable-bindings* nil
  "Hash table of binding -> t for bindings that are targets of variable-write.")

(defvar *wgsl-line-indent* nil
  "When set to an integer, the current statement's indent level.
Enables multi-line formatting for long function calls (>= 4 args).")

(defun print-wgsl-function-body (func stage stream)
  "Print the body of a WGSL function."
  (let ((*wgsl-mutable-bindings* (collect-mutable-bindings (body func))))
    (loop for form in (body func)
          do (print-wgsl-statement form stage stream 4))))

;;; Output binding detection

(defun is-wgsl-output-binding-p (binding)
  "Check if a binding is an output binding."
  (or (member binding (wgsl-outputs *wgsl-context*))
      (and (typep binding 'interface-binding)
           (let* ((sb (stage-binding binding))
                  (iq (interface-qualifier sb))
                  (iq-key (if (consp iq) (car iq) iq)))
             (eq iq-key :out)))
      (loop for out in (wgsl-outputs *wgsl-context*)
            thereis (eq (name binding) (name out)))))

;;; Helper: check if a form always exits (return/discard) so else can be lifted

(defun form-always-exits-p (form)
  "Returns true if FORM unconditionally returns or discards."
  (typecase form
    (function-call
     (let ((fname (name (called-function form))))
       (or (eq fname 'return)
           (eq fname 'cl-webgpu/shader/internal:discard))))
    ((or explicit-progn implicit-progn)
     (and (body form) (form-always-exits-p (car (last (body form))))))
    (binding-scope
     (and (body form) (form-always-exits-p (car (last (body form))))))
    (if-form
     (and (then-form form) (else-form form)
          (form-always-exits-p (then-form form))
          (form-always-exits-p (else-form form))))
    (t nil)))

;;; Statement printer

(defun print-wgsl-statement (form stage stream indent)
  "Print a single statement in WGSL syntax."
  (let ((indent-str (make-string indent :initial-element #\Space)))
    (typecase form
      ;; Variable assignment
      (variable-write
       (let* ((binding (binding form))
              (value (value form)))
         (cond
           ;; Handle slot-access binding (e.g. output.field = ...)
           ((typep binding 'slot-access)
            (let* ((b (binding binding))
                   (field (field binding)))
              (when (typep b 'variable-read)
                (let ((vr-binding (binding b)))
                  (when (typep vr-binding 'interface-binding)
                    (let* ((sb (stage-binding vr-binding))
                           (iq (interface-qualifier sb))
                           (iq-key (if (consp iq) (car iq) iq)))
                      (case iq-key
                        (:out
                         (format stream "~aoutput.~a = ~a;~%"
                                 indent-str
                                 (%translate-name field)
                                 (print-wgsl-top-expression value stage))
                         (return-from print-wgsl-statement))
                        (:uniform
                         (format stream "~auniforms.~a = ~a;~%"
                                 indent-str
                                 (%translate-name field)
                                 (print-wgsl-top-expression value stage))
                         (return-from print-wgsl-statement)))))))
              (format stream "~a~a.~a = ~a;~%"
                      indent-str
                      (print-wgsl-expression b stage)
                      (%translate-name field)
                      (print-wgsl-top-expression value stage))))
           ;; Handle swizzle-access binding (e.g. (setf (.x uv) ...)) --
           ;; PRINT-WGSL-EXPRESSION already prints a SWIZZLE-ACCESS read
           ;; correctly (recursing into its underlying binding), so reuse it
           ;; for the write target instead of TRANSLATE-NAME, whose generic
           ;; SWIZZLE-ACCESS method interpolates the raw Lisp object with ~a.
           ((typep binding 'swizzle-access)
            (format stream "~a~a = ~a;~%"
                    indent-str
                    (print-wgsl-expression binding stage)
                    (print-wgsl-top-expression value stage)))
           ;; Handle output binding -> output.name

           ;; Handle any output binding -> output.name
           ((is-wgsl-output-binding-p binding)
            (format stream "~aoutput.~a = ~a;~%"
                    indent-str
                    (translate-name binding)
                    (print-wgsl-top-expression value stage)))
           ;; Regular local variable assignment
           (t
            (let ((*wgsl-line-indent* indent))
              (format stream "~a~a = ~a;~%"
                      indent-str
                      (translate-name binding)
                      (print-wgsl-top-expression value stage)))))))

      ;; If/else
      (if-form
       (labels ((wgsl-inline-p (f)
                  "Return T if F is a simple statement that fits on one line."
                  (typecase f
                    (variable-write t)
                    (function-call
                     (let ((nm (name (called-function f))))
                       (or (eq nm 'cl-webgpu/shader/internal:discard)
                           (and (eq nm 'return) (null (arguments f))))))
                    ;; binding-scope checked before implicit-progn since it inherits from it;
                    ;; a binding-scope always has declarations so it's never a one-liner
                    (binding-scope nil)
                    ((or implicit-progn explicit-progn)
                     (and (= 1 (length (body f)))
                          (wgsl-inline-p (first (body f)))))
                    (t nil)))
                (if-chain-all-inline-p (form)
                  "Return T if this if/else-if chain can be fully rendered inline.
All then-branches must be inline-able, and all else-branches must be either
nil, another if-form that is also fully inline, or an inline-able statement."
                  (and (typep form 'if-form)
                       (wgsl-inline-p (then-form form))
                       (let ((e (else-form form)))
                         (or (null e)
                             (and (typep e 'if-form)
                                  (if-chain-all-inline-p e))
                             (wgsl-inline-p e)))))
                (print-stmt-inline (f)
                  "Render F as a trimmed single-line statement string."
                  (string-right-trim
                   '(#\Space #\Newline #\Return)
                   (with-output-to-string (s)
                     (print-wgsl-statement f stage s 0))))
                (print-if (form indent &optional no-leading-indent)
                  (let* ((prefix (if no-leading-indent
                                     ""
                                     (make-string indent :initial-element #\Space)))
                         (indent-str (make-string indent :initial-element #\Space))
                         (cond-expr (test-form form))
                         (then (then-form form))
                         (else (else-form form))
                         (cond-str (print-wgsl-top-expression cond-expr stage)))
                    (cond
                      ;; Inline ONLY when the entire if/else-if chain is fully inline-able
                      ((if-chain-all-inline-p form)
                       (format stream "~aif (~a) { ~a }~%"
                               prefix cond-str (print-stmt-inline then))
                       (when else
                         (cond
                           ;; else is an if-form → else if chain
                           ((typep else 'if-form)
                            (format stream "~aelse " indent-str)
                            (print-if else indent t))
                           ;; else is also inline
                           ((wgsl-inline-p else)
                            (format stream "~aelse { ~a }~%"
                                    indent-str (print-stmt-inline else))))))
                      ;; Normal multi-line then
                      (t
                       (format stream "~aif (~a) {~%" prefix cond-str)
                       (print-wgsl-statement then stage stream (+ indent 4))
                       (cond
                         ;; No else branch
                         ((not else)
                          (format stream "~a}~%" indent-str))
                         ;; Then-branch always exits — lift else to same scope
                         ((form-always-exits-p then)
                          (format stream "~a}~%" indent-str)
                          (print-wgsl-statement else stage stream indent))
                         ;; Else is itself an if-form — flatten to else if
                         ((typep else 'if-form)
                          (format stream "~a} else " indent-str)
                          (print-if else indent t))
                         ;; Normal else block
                         (t
                          (format stream "~a} else {~%" indent-str)
                          (print-wgsl-statement else stage stream (+ indent 4))
                          (format stream "~a}~%" indent-str))))))))
         (print-if form indent)))

      ;; For loop
      (for-loop
       (let ((init (init-forms form))
             (cond-forms (condition-forms form))
             (step (step-forms form)))
         (format stream "~afor (~{~a~^, ~}; ~{~a~^, ~}; ~{~a~^, ~}) {~%"
                 indent-str
                 (mapcar (lambda (f) (print-wgsl-top-expression f stage)) init)
                 (mapcar (lambda (f) (print-wgsl-top-expression f stage)) cond-forms)
                 (mapcar (lambda (f) (print-wgsl-top-expression f stage)) step))
         ;; Print body
         (loop for f in (body form)
               do (print-wgsl-statement f stage stream (+ indent 4)))
         (format stream "~a}~%" indent-str)))

      ;; Local variable binding scope (from let/let*)
      (binding-scope
       ;; Special case: single mutable binding wrapping a for-loop with no init.
       ;; Inline the var declaration into the for-loop header.
       (if (and (= 1 (length (bindings form)))
                (= 1 (length (body form)))
                (typep (first (body form)) 'for-loop)
                (null (init-forms (first (body form)))))
           (let* ((b (first (bindings form)))
                  (fl (first (body form)))
                  (b-init (when (typep b 'initialized-binding)
                            (initial-value-form b)))
                  (type-str (wgsl-translate-type
                             (or (and (boundp '*binding-types*)
                                      (gethash b *binding-types*))
                                 (value-type b))))
                  (decl (if b-init
                            (format nil "var ~a = ~a"
                                    (translate-name b)
                                    (print-wgsl-top-expression b-init stage))
                            (format nil "var ~a: ~a" (translate-name b) type-str))))
             (format stream "~afor (~a; ~{~a~^, ~}; ~{~a~^, ~}) {~%"
                     indent-str
                     decl
                     (mapcar (lambda (f) (print-wgsl-top-expression f stage))
                             (condition-forms fl))
                     (mapcar (lambda (f) (print-wgsl-top-expression f stage))
                             (step-forms fl)))
             (loop for f in (body fl)
                   do (print-wgsl-statement f stage stream (+ indent 4)))
             (format stream "~a}~%" indent-str))
           ;; Normal binding-scope: declare each binding then print body
           (progn
             (loop for b in (bindings form)
                   do (let* ((type-str (wgsl-translate-type
                                        (or (and (boundp '*binding-types*)
                                                 (gethash b *binding-types*))
                                            (value-type b))))
                             (init (when (typep b 'initialized-binding)
                                     (initial-value-form b)))
                             (mutable (and (boundp '*wgsl-mutable-bindings*)
                                          *wgsl-mutable-bindings*
                                          (gethash b *wgsl-mutable-bindings*))))
                        (cond
                          ;; Struct construction -> zero-init: var name: Type;
                          ((typep init 'struct-construction)
                           (format stream "~avar ~a: ~a;~%"
                                   indent-str (translate-name b)
                                   (wgsl-translate-type (construction-type init))))
                          ;; Mutable + zero init -> var name: Type; (no init needed)
                          ((and mutable (wgsl-is-zero-p init))
                           (format stream "~avar ~a: ~a;~%"
                                   indent-str (translate-name b) type-str))
                          ;; Immutable with init -> let name = value;
                          ((and init (not mutable))
                           (format stream "~alet ~a = ~a;~%"
                                   indent-str (translate-name b)
                                   (print-wgsl-top-expression init stage)))
                          ;; Mutable + scalar literal init -> var name: T = value;
                          ((and mutable init (typep init 'number))
                           (format stream "~avar ~a: ~a = ~a;~%"
                                   indent-str (translate-name b) type-str
                                   (print-wgsl-top-expression init stage)))
                          ;; Mutable + type-constructor init -> var name = T(args);
                          ((and mutable (wgsl-is-type-constructor-p init))
                           (format stream "~avar ~a = ~a;~%"
                                   indent-str (translate-name b)
                                   (print-wgsl-top-expression init stage)))
                          ;; Mutable + boolean literal init -> var name: bool = value;
                          ((and mutable (or (eql init t) (eql init nil)))
                           (format stream "~avar ~a: ~a = ~a;~%"
                                   indent-str (translate-name b) type-str
                                   (print-wgsl-top-expression init stage)))
                          ;; Mutable + other init -> var name = value;
                          (mutable
                           (format stream "~avar ~a = ~a;~%"
                                   indent-str (translate-name b)
                                   (print-wgsl-top-expression init stage)))
                          ;; No init -> var name: type;
                          (t
                           (format stream "~avar ~a: ~a;~%"
                                   indent-str (translate-name b) type-str)))))
             ;; Print body forms
             (loop for f in (body form)
                   do (print-wgsl-statement f stage stream indent)))))

      ;; Explicit progn — just iterate body
      (explicit-progn
       (loop for f in (body form)
             do (print-wgsl-statement f stage stream indent)))

      ;; Implicit progn
      (implicit-progn
       (loop for f in (body form)
             do (print-wgsl-statement f stage stream indent)))

      ;; Function call as statement
      (function-call
       (let* ((f (called-function form))
              (fname (name f)))
         (cond
           ;; return
           ((eq fname 'return)
            (if (arguments form)
                (let ((*wgsl-line-indent* indent))
                  (format stream "~areturn ~a;~%"
                          indent-str
                          (print-wgsl-top-expression (first (arguments form)) stage)))
                (format stream "~areturn;~%" indent-str)))
           ;; discard
           ((eq fname 'cl-webgpu/shader/internal:discard)
            (format stream "~adiscard;~%" indent-str))
           ;; values (used for implicit return)
           ((eq fname 'values)
            (when (arguments form)
              (format stream "~a~a;~%"
                      indent-str
                      (print-wgsl-expression (first (arguments form)) stage))))
           ;; Internal operator used as statement (e.g. incf/decf)
           ((and (typep f 'internal-function)
                 (gethash fname *internal-function-printers*))
            (format stream "~a~a;~%"
                    indent-str
                    (print-wgsl-expression form stage)))
           ;; Regular function call as statement
           (t
            (format stream "~a~a;~%"
                    indent-str
                    (print-wgsl-expression form stage))))))

      ;; Fallback for unknown forms
      (t
       (format stream "~a// TODO: unhandled ~a~%" indent-str (type-of form))))))

;;; Binding mutability check

(defun collect-mutable-bindings (forms)
  "Walk forms and collect all bindings that are written to."
  (let ((ht (make-hash-table)))
    (labels ((walk-form (form)
               (typecase form
                 (variable-write
                  (let ((b (binding form)))
                    (cond
                      ;; Direct variable-read target: unwrap to actual binding
                      ((typep b 'variable-read)
                       (setf (gethash (binding b) ht) t))
                      ;; Direct binding target
                      ((typep b 'binding)
                       (setf (gethash b ht) t))
                      ;; Slot-access: walk deeper to find mutations
                      ((typep b 'slot-access)
                       (walk-form b))
                      ;; Swizzle-access (e.g. (setf (.x uv) ...)): the write
                      ;; target is the vector variable underneath, not the
                      ;; swizzle-access node itself -- unwrap directly rather
                      ;; than recursing through WALK-FORM's SWIZZLE-ACCESS
                      ;; arm, which bottoms out at a no-op VARIABLE-READ leaf
                      ;; and would never mark anything mutable.
                      ((typep b 'swizzle-access)
                       (let ((inner (binding b)))
                         (cond
                           ((typep inner 'variable-read)
                            (setf (gethash (binding inner) ht) t))
                           ((typep inner 'binding)
                            (setf (gethash inner ht) t)))))))
                  (walk-form (value form)))
                 (if-form
                  (walk-form (test-form form))
                  (when (then-form form) (walk-form (then-form form)))
                  (when (else-form form) (walk-form (else-form form))))
                 (function-call
                  (mapc #'walk-form (arguments form)))
                 (binding-scope
                  (loop for b in (bindings form)
                        when (and (typep b 'initialized-binding)
                                  (initial-value-form b))
                          do (walk-form (initial-value-form b)))
                  (mapc #'walk-form (body form)))
                 ((or explicit-progn implicit-progn)
                  (mapc #'walk-form (body form)))
                 (for-loop
                  (mapc #'walk-form (init-forms form))
                  (mapc #'walk-form (condition-forms form))
                  (mapc #'walk-form (step-forms form))
                  (mapc #'walk-form (body form)))
                 (slot-access
                  (walk-form (binding form)))
                 (swizzle-access
                  (walk-form (binding form)))
                 (array-access
                  (walk-form (binding form)))
                 (variable-read)
                 (initialized-binding
                  (when (initial-value-form form)
                    (walk-form (initial-value-form form))))
                 (t))))
      (mapc #'walk-form forms))
    ht))

;;; Top-level expression (strips redundant outer parens)
(defun print-wgsl-top-expression (expr stage)
  "Print expression for statement context (strips outer parens)."
  (strip-outer-parens (print-wgsl-expression expr stage)))

;;; Strip outer parentheses helper
(defun strip-outer-parens (s)
  "Strip matching outer parentheses from a string if present."
  (if (and (> (length s) 2)
           (char= (char s 0) #\()
           (char= (char s (1- (length s))) #\)))
      ;; Check if parens actually match (not just first/last chars of different groups)
      (let ((depth 0)
            (match t))
        (loop for i from 0 below (length s)
              for c = (char s i)
              do (cond ((char= c #\() (incf depth))
                       ((char= c #\)) (decf depth)))
                 (when (and (zerop depth) (< i (1- (length s))))
                   (setf match nil)
                   (return)))
        (if match
            (subseq s 1 (1- (length s)))
            s))
      s))

;;; WGSL-specific precedence-aware binary operator printing

(defun wgsl-op-precedence (op)
  "Return WGSL operator precedence for OP (higher = tighter binding), or nil."
  (case op
    ((* / cl-webgpu/shader::mod cl-webgpu/shader/internal::mod) 13)
    ((+ -) 12)
    ((ash cl-webgpu/shader/internal::<< cl-webgpu/shader/internal::>>) 11)
    ((< > <= >=) 10)
    ((= /=) 9)
    ((logand) 8)
    ((logxor) 7)
    ((logior) 6)
    ((and) 5)
    ((or cl-webgpu/shader/internal::^^) 4)
    (t nil)))

(defun wgsl-op-c-symbol (op)
  "Return the WGSL infix operator string for OP, or nil if not handled here."
  (case op
    ((+) "+") ((-) "-") ((*) "*") ((/) "/")
    ((cl-webgpu/shader::mod cl-webgpu/shader/internal::mod) "%")
    ((and) "&&") ((or) "||") ((cl-webgpu/shader/internal::^^) "^^")
    ((=) "==") ((/=) "!=") ((<) "<") ((>) ">") ((<=) "<=") ((>=) ">=")
    ((logand) "&") ((logior) "|") ((logxor) "^")
    ((ash cl-webgpu/shader/internal::<<) "<<") ((cl-webgpu/shader/internal::>>) ">>")
    (t nil)))

(defun wgsl-is-zero-p (init)
  "Return T if INIT is a zero scalar literal or a type-constructor with all-zero args."
  (cond
    ;; Zero number literal
    ((and (typep init 'number) (zerop init)) t)
    ;; Type constructor with all zero args (vec3(0.0), etc.)
    ((typep init 'function-call)
     (and (typep (called-function init) 'internal-function)
          (let* ((fname (name (called-function init)))
                 (sname (string-downcase (symbol-name fname))))
            (gethash sname *wgsl-type-constructor-names*))
          (let ((ctor-args (arguments init)))
            (and (>= (length ctor-args) 2)
                 (every (lambda (a) (and (typep a 'number) (zerop a)))
                        ctor-args)))))
    (t nil)))

(defun wgsl-get-expr-type (expr)
  "Return the inferred concrete-type of EXPR from *binding-types*, or nil."
  (typecase expr
    (variable-read
     (when (and (boundp '*binding-types*) *binding-types*)
       (gethash (binding expr) *binding-types*)))
    (t nil)))

(defun wgsl-type-uint-p (type)
  "Return T if TYPE is a uint/u32 concrete type."
  (and type
       (typep type 'concrete-type)
       (member (name type) '(:uint cl-webgpu/shader/internal::uint) :test #'eq)))

(defun wgsl-is-type-constructor-p (init)
  "Return T if INIT is a type-constructor call (vec2, vec3, f32, etc.)."
  (and (typep init 'function-call)
       (typep (called-function init) 'internal-function)
       (let* ((fname (name (called-function init)))
              (sname (string-downcase (symbol-name fname))))
         (gethash sname *wgsl-type-constructor-names*))))

(defun ensure-parens (s)
  "Wrap string S in parentheses (always adds them)."
  (format nil "(~a)" s))

(defun wgsl-expr-parens (expr stage parent-prec is-right &optional parent-op)
  "Print EXPR, adding parentheses only when operator precedence requires it.
PARENT-PREC: precedence of the enclosing operator.
IS-RIGHT: T if EXPR is the right-hand child.
PARENT-OP: the parent operator symbol (for associativity)."
  (let* ((fname (when (and (typep expr 'function-call)
                           (typep (called-function expr) 'internal-function))
                  (name (called-function expr))))
         (child-prec (when fname (wgsl-op-precedence fname)))
         (s (print-wgsl-expression expr stage)))
    (if (null child-prec)
        ;; Not a known binary op: strip GLSL-added outer parens
        (strip-outer-parens s)
        ;; Binary op: add parens only when precedence demands it
        (cond
          ;; Child binds looser than parent → must parenthesize
          ((< child-prec parent-prec)
           (ensure-parens s))
          ;; Same precedence, right child of non-associative parent (- or /)
          ((and (= child-prec parent-prec) is-right
                (member parent-op '(- /)))
           (ensure-parens s))
          ;; Otherwise strip redundant GLSL outer parens
          (t (strip-outer-parens s))))))

(defun wgsl-format-binary-op (fname args stage)
  "Format a binary/unary operator for WGSL with proper precedence.
Returns nil if FNAME is not a handled operator."
  (let ((my-prec (wgsl-op-precedence fname))
        (c-op (wgsl-op-c-symbol fname)))
    (when (and my-prec c-op)
      (case (length args)
        ;; Unary negation — use prec 12 so multiplicative/divisive args (prec 13) don't get
        ;; wrapped: -a*b = -(a*b) in WGSL, no parens needed. Additive (prec 12) still gets parens.
        (1 (when (eq fname '-)
             (let ((a-str (wgsl-expr-parens (first args) stage 12 t '-)))
               (format nil "-~a" a-str))))
        ;; Binary / N-ary
        (otherwise
         (let* (;; Detect u32 context: if any arg has u32 type, integer literals get 'u' suffix
                (u32ctx (when (member fname '(+ - * / cl-webgpu/shader::mod cl-webgpu/shader/internal::mod) :test #'eq)
                          (some (lambda (a) (wgsl-type-uint-p (wgsl-get-expr-type a)))
                                args)))
                (rendered (loop for a in args
                                for i from 0
                                collect (if (and u32ctx (typep a 'integer))
                                            (format nil "~du" a)
                                            (wgsl-expr-parens a stage my-prec (> i 0) fname))))
                ;; Build "a op b op c ..." string
                (parts (loop for (s . rest) on rendered
                             collect s
                             when rest collect c-op)))
           (format nil "~{~a~^ ~}" parts)))))))

;;; Integer suffix helper
(defun wgsl-integer-suffix (type-name args)
  "If TYPE-NAME is uint/int and ARGS is a single integer literal, return suffix form string.
Returns nil if not applicable."
  (when (and (= 1 (length args))
             (typep (first args) 'integer))
    (let ((val (first args)))
      (cond
        ((member type-name '(:uint cl-webgpu/shader/internal::uint) :test #'eq)
         (format nil "~du" val))
        ((member type-name '(:int cl-webgpu/shader/internal::int) :test #'eq)
         (format nil "~di" val))
        (t nil)))))

;;; Expression printer

(defun render-fn-call-wgsl (fn-name rendered-args &key trailing-comma)
  "Render a WGSL function call, using multi-line format when the call is long.
When *wgsl-line-indent* is set and the single-line form exceeds 70 chars,
formats each arg on its own line and ) on its own line.
When trailing-comma is T, adds a comma after the last arg (used for
user-defined function calls which use trailing-comma style)."
  (let ((single-line (format nil "~a(~{~a~^, ~})" fn-name rendered-args)))
    (if (and *wgsl-line-indent*
             (> (+ *wgsl-line-indent* (length single-line)) 70))
        (let ((il *wgsl-line-indent*)
              (*wgsl-line-indent* nil))
          (with-output-to-string (s)
            (format s "~a(~%" fn-name)
            (loop for (a-str . rest) on rendered-args
                  do (format s "~a~a~a~%"
                             (make-string (+ il 4) :initial-element #\Space)
                             a-str
                             (if (or rest trailing-comma) "," "")))
            (format s "~a)" (make-string il :initial-element #\Space))))
        single-line)))

(defun print-wgsl-expression (expr stage)
  "Convert an expression to a WGSL syntax string."
  (typecase expr
    ;; Variable read
    (variable-read
     (let* ((binding (binding expr)))
       (cond
         ;; Input interface binding -> input.name
         ((member binding (wgsl-inputs *wgsl-context*))
          (format nil "input.~a" (translate-name binding)))
         ;; Interface binding dispatch
         ((typep binding 'interface-binding)
          (let* ((sb (stage-binding binding))
                 (iq (interface-qualifier sb))
                 (iq-key (if (consp iq) (car iq) iq))
                 (lq (layout-qualifier sb)))
            (case iq-key
              (:in (format nil "input.~a" (translate-name binding)))
              (:out (format nil "output.~a" (translate-name binding)))
              (:uniform
               ;; Explicitly-bound uniforms are standalone vars, not in user_uniforms struct
               (if (and (getf lq :group) (getf lq :binding))
                   (translate-name binding)
                   (format nil "user_uniforms.~a" (translate-name binding))))
              (t (translate-name binding)))))
         ;; Local/other
         (t (translate-name binding)))))

    ;; Slot access (struct field)
    (slot-access
     (let* ((b (binding expr))
            (field (field expr)))
       (when (typep b 'variable-read)
         (let ((vr-binding (binding b)))
           (when (typep vr-binding 'interface-binding)
             (let* ((sb (stage-binding vr-binding))
                    (iq (interface-qualifier sb))
                    (iq-key (if (consp iq) (car iq) iq)))
               (return-from print-wgsl-expression
                 (case iq-key
                   (:out (format nil "output.~a" (translate-slot-name field sb)))
                   (:in (format nil "input.~a" (translate-slot-name field sb)))
                   (:uniform
                    (let ((lq (layout-qualifier sb)))
                      (if (and (getf lq :group) (getf lq :binding))
                          (format nil "~a.~a" (translate-name vr-binding)
                                  (translate-slot-name field sb))
                          (format nil "user_uniforms.~a" (translate-slot-name field sb)))))
                   (t (format nil "~a.~a"
                              (print-wgsl-expression b stage)
                              (translate-slot-name field sb)))))))))
       (format nil "~a.~a"
               (print-wgsl-expression b stage)
               (%translate-name field))))

    ;; Swizzle access (.xyz, .xy, etc)
    (swizzle-access
     (format nil "~a.~a"
             (print-wgsl-expression (binding expr) stage)
             (string-downcase (if (symbolp (field expr))
                                  (symbol-name (field expr))
                                  (field expr)))))

    ;; Array access
    (array-access
     (format nil "~a[~a]"
             (print-wgsl-expression (binding expr) stage)
             (let ((idx (index expr)))
               (if (typep idx '(or variable-read function-call
                                   slot-access swizzle-access array-access))
                   (print-wgsl-expression idx stage)
                   idx))))

    ;; Function call / operator
    (function-call
     (let ((f (called-function expr))
           (args (arguments expr)))
       (typecase f
         ;; Internal function (operators, builtins that have special printers)
         (internal-function
          (let* ((fname (name f))
                 ;; First try WGSL-specific precedence-aware binary op printer
                 (wgsl-binop (wgsl-format-binary-op fname args stage)))
            (or wgsl-binop
                (let ((printer (gethash fname *internal-function-printers*)))
                  (if printer
                      ;; Use the GLSL printer, then strip outer parens for unary ops
                      (let ((result (with-output-to-string (s)
                                      (let ((*standard-output* s))
                                        (funcall printer s
                                                 (mapcar (lambda (a)
                                                           (print-wgsl-expression a stage))
                                                         args)
                                                 :call expr)))))
                        ;; For non-binary ops (not, 1+, 1-, etc.): strip outer parens
                        ;; Binary ops already handled above; these are unary helpers
                        (if (wgsl-op-precedence fname)
                            result  ; binary op fell through (shouldn't happen)
                            (strip-outer-parens result)))
                      ;; Internal function without special printer (type constructors etc.)
                      (let* ((sname (string-downcase (symbol-name fname)))
                             (is-type-ctor (gethash sname *wgsl-type-constructor-names*)))
                        ;; Try integer suffix form first (e.g. uint(255) -> 255u)
                        (or (and is-type-ctor
                                 (wgsl-integer-suffix fname args))
                            (let ((wgsl-name (if is-type-ctor
                                                 (wgsl-type-name (intern (string-upcase sname) :keyword))
                                                 ;; ATAN is DSL-overloaded (mirroring GLSL's
                                                 ;; atan(y) / atan(y,x)) but WGSL has no 2-arg
                                                 ;; atan -- its 2-arg builtin is separately
                                                 ;; named atan2(y, x). Route by arity here
                                                 ;; rather than adding a second DSL symbol.
                                                 (if (and (eq fname 'atan) (= (length args) 2))
                                                     "atan2"
                                                     (or (gethash fname *wgsl-function-map*)
                                                         (translate-name f))))))
                              (render-fn-call-wgsl
                               wgsl-name
                               (mapcar (lambda (a)
                                         (strip-outer-parens (print-wgsl-expression a stage)))
                                       args))))))))))

         ;; Regular function call
         (t
          (let* ((fname (name f))
                 (translated (translate-name f))
                 (wgsl-name (or (gethash fname *wgsl-function-map*)
                                translated)))
            ;; Check if this is a type constructor
            (cond
              ;; Texture sampling — WGSL uses textureSample()
              ((and (typep f 'function-binding)
                    (member fname '(texture texture-lod)))
               (if (eq fname 'texture-lod)
                   (format nil "textureSampleLevel(~a_texture, ~a_sampler, ~a, ~a)"
                           (translate-name (first args))
                           (translate-name (first args))
                           (strip-outer-parens (print-wgsl-expression (second args) stage))
                           (strip-outer-parens (print-wgsl-expression (third args) stage)))
                   (format nil "textureSample(~a_texture, ~a_sampler, ~a)"
                           (translate-name (first args))
                           (translate-name (first args))
                           (strip-outer-parens (print-wgsl-expression (second args) stage)))))

              ;; texel-fetch -> textureLoad
              ((and (typep f 'function-binding)
                    (eq fname 'texel-fetch))
               (format nil "textureLoad(~a_texture, ~a, ~a)"
                       (translate-name (first args))
                       (strip-outer-parens (print-wgsl-expression (second args) stage))
                       (strip-outer-parens (print-wgsl-expression (third args) stage))))

              ;; Type constructor: vec3(...) -> vec3<f32>(...)
              ((gethash (string-downcase (symbol-name fname))
                        *wgsl-type-constructor-names*)
               ;; Try integer suffix form first
               (or (wgsl-integer-suffix fname args)
                   (let ((wgsl-type (wgsl-type-name
                                     (intern (string-upcase (symbol-name fname))
                                             :keyword))))
                     (render-fn-call-wgsl
                      wgsl-type
                      (mapcar (lambda (a)
                                (strip-outer-parens (print-wgsl-expression a stage)))
                              args)))))

              ;; Regular function call — potentially multi-line for long calls
              ;; User-defined functions use trailing-comma style
              (t
               (render-fn-call-wgsl
                wgsl-name
                (mapcar (lambda (a)
                          (strip-outer-parens (print-wgsl-expression a stage)))
                        args)
                :trailing-comma t))))))))

    ;; Number literals
    (number
     (if (floatp expr)
         (format nil "~f" expr)
         (format nil "~d" expr)))

    ;; Boolean
    ((eql t) "true")
    ((eql nil) "false")

    ;; Initialized binding (used as expression in some contexts)
    (initialized-binding
     (let ((init (initial-value-form expr)))
       (if init
           (print-wgsl-expression init stage)
           (translate-name expr))))

    ;; Variable write as expression (assignment expression)
    (variable-write
     (let ((binding (binding expr))
           (value (value expr)))
       (cond
         ((is-wgsl-output-binding-p binding)
          (format nil "(output.~a = ~a)"
                  (translate-name binding)
                  (print-wgsl-top-expression value stage)))
         (t
          (format nil "(~a = ~a)"
                  (translate-name binding)
                  (print-wgsl-top-expression value stage))))))

    ;; If-form as expression (ternary)
    (if-form
     (format nil "select(~a, ~a, ~a)"
             (print-wgsl-expression (else-form expr) stage)
             (print-wgsl-expression (then-form expr) stage)
             (print-wgsl-expression (test-form expr) stage)))

    ;; Struct construction
    (struct-construction
     (format nil "~a()" (wgsl-translate-type (construction-type expr))))

    ;; Array initialization
    (array-initialization
     (format nil "array(~{~a~^, ~})"
             (mapcar (lambda (a) (print-wgsl-expression a stage))
                     (arguments expr))))

    ;; Fallback
    (t
     (format nil "/* unknown: ~a */" (type-of expr)))))


;;; Combined multi-stage WGSL output

(defun generate-wgsl-combined (stages-data)
  "Generate a single WGSL string with multiple shader stages.
STAGES-DATA is a list of (stage objects inferred-types main-binding) quads."
  (let ((*wgsl-name-mode* t))
   (with-output-to-string (*standard-output*)
    ;; Collect all structs and uniforms first (needed to detect texture type override)
    (let ((seen-structs (make-hash-table))
          (all-uniforms nil)
          (all-buffers nil))
      ;; First pass: collect all structs, uniforms, and storage buffers
      (loop for (stage objects inferred-types main-binding) in stages-data
            do (let ((*current-shader-stage* stage))
                 (loop for obj in objects
                       when (and (typep obj 'struct-type)
                                 (not (gethash (name obj) seen-structs))
                                 (not (and *emit-ugly-preamble* (internal obj))))
                         do (setf (gethash (name obj) seen-structs) t))
                 (multiple-value-bind (inputs outputs uniforms buffers)
                     (collect-wgsl-bindings objects stage)
                   (declare (ignore inputs outputs))
                   (loop for u in uniforms
                         unless (member (name u) all-uniforms :key #'name)
                           do (push u all-uniforms))
                   (loop for b in buffers
                         unless (member (name b) all-buffers :key #'name)
                           do (push b all-buffers)))))

      ;; Detect texture type override at group 0 binding 1 (for array/cube shaders)
      (let ((preamble-texture-type "texture_2d<f32>"))
        (when *emit-ugly-preamble*
          (loop for u in all-uniforms
                for sb = (stage-binding u)
                for lq = (layout-qualifier sb)
                for grp = (getf lq :group)
                for bnd = (getf lq :binding)
                when (and (eql grp 0) (eql bnd 1))
                  do (let* ((type (value-type sb))
                            (type-name (name type)))
                       (setf preamble-texture-type
                             (case type-name
                               ((:sampler-2d-array :isampler-2d-array :usampler-2d-array)
                                "texture_2d_array<f32>")
                               ((:sampler-cube :isampler-cube :usampler-cube)
                                "texture_cube<f32>")
                               (t "texture_2d<f32>")))
                       (return))))

        ;; Emit ugly preamble once (with possibly overridden texture type)
        (when *emit-ugly-preamble*
          (print-wgsl-ugly-preamble *standard-output* preamble-texture-type))

        ;; Emit structs (now that preamble is done)
        (loop for (stage objects inferred-types main-binding) in stages-data
              do (let ((*current-shader-stage* stage))
                   (loop for obj in objects
                         when (and (typep obj 'struct-type)
                                   (gethash (name obj) seen-structs)
                                   (not (and *emit-ugly-preamble* (internal obj))))
                           do (print-wgsl-struct obj *standard-output*)
                              (remhash (name obj) seen-structs))))

        ;; Emit user uniforms once (filter internal AND group-0-binding-1 overrides)
        (let ((uniforms (if *emit-ugly-preamble*
                            (remove-if (lambda (u)
                                         (or (internal u)
                                             ;; Suppress binding overridden by preamble
                                             (let* ((sb (stage-binding u))
                                                    (lq (layout-qualifier sb)))
                                               (and (eql (getf lq :group) 0)
                                                    (eql (getf lq :binding) 1)))))
                                       (nreverse all-uniforms))
                            (nreverse all-uniforms))))
          (when uniforms
            (print-wgsl-user-uniforms uniforms *standard-output*)))

        ;; Emit storage buffers (var<storage, read_write>) once, deduplicated
        (let ((buffers (nreverse all-buffers)))
          (when buffers
            (print-wgsl-user-buffers buffers *standard-output*)))))

    ;; Collect helper functions (deduplicated) and entry points
    (let ((seen-helpers (make-hash-table)))
      ;; First pass: emit helper functions
      (loop for (stage objects inferred-types main-binding) in stages-data
            do (let ((*current-shader-stage* stage)
                     (*print-as-main* main-binding))
                 (multiple-value-bind (inputs outputs uniforms buffers)
                     (collect-wgsl-bindings objects stage)
                   (declare (ignore buffers))
                   (let ((*wgsl-context* (make-instance 'wgsl-shader-context
                                                        :stage stage)))
                     (setf (wgsl-inputs *wgsl-context*) inputs
                           (wgsl-outputs *wgsl-context*) outputs
                           (wgsl-uniforms *wgsl-context*) uniforms)
                     (loop for object in objects
                           when (typep object 'global-function)
                             do (let ((overloads (gethash object inferred-types)))
                                  (assert overloads)
                                  (unless (or (eq object main-binding)
                                              (gethash (name object) seen-helpers))
                                    (setf (gethash (name object) seen-helpers) t)
                                    (loop for overload in overloads
                                          for *binding-types* = (gethash overload
                                                                        (final-binding-type-cache object))
                                          do (assert *binding-types*)
                                             (print-wgsl-function object stage *standard-output*)))))))))

      ;; Now emit entry points
      (loop for (stage objects inferred-types main-binding) in stages-data
            do (let* ((*current-shader-stage* stage)
                      (*print-as-main* main-binding))
                 (when main-binding
                   ;; Rebuild context for this stage
                   (multiple-value-bind (inputs outputs uniforms buffers)
                       (collect-wgsl-bindings objects stage)
                     (declare (ignore buffers))
                     (let ((*wgsl-context* (make-instance 'wgsl-shader-context
                                                          :stage stage)))
                       (setf (wgsl-inputs *wgsl-context*) inputs
                             (wgsl-outputs *wgsl-context*) outputs
                             (wgsl-uniforms *wgsl-context*) uniforms)
                       (let ((overloads (gethash main-binding inferred-types)))
                         (assert overloads)
                         (loop for overload in overloads
                               for *binding-types* = (gethash overload
                                                             (final-binding-type-cache main-binding))
                               do (assert *binding-types*)
                                  (print-wgsl-function main-binding stage *standard-output*))))))))))))
