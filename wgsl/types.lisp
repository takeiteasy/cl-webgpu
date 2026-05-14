(in-package #:cl-webgpu/shader)

(defclass generic-type ()
  ((name :accessor name :initarg :name)
   (target-name :accessor target-name :initarg :target-name :initform nil)
   ;; flag indicating we don't need to dump a definition into generated source
   (internal :accessor internal :initform nil :initarg :internal)
   (modified :initform nil :accessor :modified)))


(defclass concrete-type (generic-type)
  ;; list of types we can implicitly cast this type to
  ((implicit-casts-to :initform nil :accessor implicit-casts-to
                      :initarg :casts-to)
   ;; list of types that can be implicitly cast to this one
   (implicit-casts-from :initform nil :accessor implicit-casts-from
                        :initarg :casts-from)
   ;; same thing, but for types allowed by constructors
   ;; (constructors accept all base numerical types with same number
   ;;  of components, so don't need to separate to/from)
   (explicit-casts :initform nil :accessor explicit-casts
                   :initarg :explicit-casts)
   ;; size of type if a member of a scalar/vector base type set, or nil
   ;; ex :float -> 1, :vec2 -> 2, etc
   (scalar/vector-size :initarg :scalar/vector-size :initform nil
                       :accessor scalar/vector-size)
   ;; types in scalar/vector base type set that includes this type, if any
   ;; vector of concrete types, ex #(:bool :bvec2 :bvec3 :bvec4)
   ;; (aref scalar/vector-set scalar/vector-size) == this type, if set
   (scalar/vector-set :initarg :scalar/vector-set :initform nil
                      :accessor scalar/vector-set)
   ;; type of elements of vector/matrix
   (base-type :initarg :base-type :initform nil :accessor base-type)))

;; should these be concrete-type? or some common superclass?
;; for now assuming everything not a constrained-type is a concrete type
(defclass array-type (generic-type)
  ((base-type :initarg :base-type :accessor base-type)
   (array-size :initarg :array-size :accessor array-size)))

(defclass aggregate-type (generic-type bindings)
  ())

(defclass struct-type (aggregate-type binding-with-dependencies)
  ())

(defmethod implicit-casts-to ((s t))
  nil)

(defmethod implicit-casts-from ((s t))
  nil)

(defclass interface-type (aggregate-type)
  ())

#++ ;; uniform-blocks are a variant of interface...
(defclass uniform-block-type (aggregate-type)
  ())


(defmacro %shader-macro (name lambda-list &body body)
  `(let ((cl-webgpu/shader::*environment* cl-webgpu/shader/internal::*shader-base-environment*))
     (cl-webgpu/shader::add-macro ',name
                              (lambda (form env)
                                (declare (ignorable env))
                                (let (,@(when (eq '&whole (car lambda-list))
                                          (pop lambda-list)
                                          (list
                                           (list (pop lambda-list)
                                                 'form))))
                                  (destructuring-bind ,lambda-list
                                      (cdr form)
                                    ,@body))))))

(defmacro %shader-compiler-macro (name lambda-list &body body)
  `(let ((cl-webgpu/shader::*environment* cl-webgpu/shader/internal::*shader-base-environment*))
     (cl-webgpu/shader::add-compiler-macro ',name
                                       (lambda (form env)
                                         (declare (ignore env))
                                         (let (,@(when (eq '&whole
                                                           (car lambda-list))
                                                   (pop lambda-list)
                                                   (list
                                                    (list (pop lambda-list)
                                                          'form))))
                                           (destructuring-bind ,lambda-list
                                               (cdr form)
                                             ,@body))))))

(%shader-macro defstruct (name-and-options &body slots)
  (let* ((name-opts (alexandria:ensure-list name-and-options))
         (name (first name-opts))
         (target-name (when (stringp (second name-opts)) (second name-opts))))
    (flet ((make-slot-binding (%sname type args)
             (let* ((sname (if (consp %sname) (first %sname) %sname))
                    (target-sname (when (consp %sname) (second %sname)))
                    (location (getf args :location))
                    (builtin (getf args :builtin)))
               (if (or location builtin)
                   (make-instance 'annotated-binding
                                  :name sname
                                  :target-name target-sname
                                  :value-type (get-type-binding type)
                                  :location location
                                  :builtin builtin)
                   (make-instance 'binding
                                  :name sname
                                  :target-name target-sname
                                  :value-type (get-type-binding type))))))
      (let ((old (gethash name (types *environment*))))
        (if old
            (reinitialize-instance
             old
             :name name
             :target-name target-name
             :bindings
             (loop for (sname type . args) in slots
                   collect (make-slot-binding sname type args)))
            (setf (gethash name (types *environment*))
                  (make-instance
                   'struct-type
                   :name name
                   :target-name target-name
                   :bindings
                   (loop for (sname type . args) in slots
                         collect (make-slot-binding sname type args))))))))
  nil)

(defclass interface-stage-binding (place)
  ((binding :accessor binding :initarg :binding)
   (stage :accessor stage :initarg :stage)
   (interface-qualifier :accessor interface-qualifier :initarg :interface-qualifier)
   (layout-qualifier :accessor layout-qualifier :initarg :layout-qualifier :initform nil)
   (interface-block :accessor interface-block :initform nil :initarg :interface-block)
   (array-size :accessor array-size :initform nil :initarg :array-size)
   (default :accessor default :initform nil :initarg :default)))

(defparameter *current-shader-stage* nil)

(defclass interface-binding (binding binding-with-dependencies)
  ;; binding of a name to an interface in a particular stage
  ;; (just a plist stage -> binding for now, so we don't need to enumerate
  ;;  them all in advance...)
  ;; use stage T for default, or 'all stages' binding
  ((stage-bindings :accessor stage-bindings :initarg :stage-bindings
                   :initform nil)
   ;; flag indicating we don't need to dump a definition into generated source
   (internal :accessor internal :initform nil :initarg :internal)
   (array-size :accessor array-size :initform nil :initarg :array-size)))

(defmethod stage-binding (binding)
  nil)

(defmethod stage-binding ((binding interface-binding))
  (let ((sb (or (getf (stage-bindings binding)
                      *current-shader-stage*)
                (getf (stage-bindings binding)
                      t))))
    sb))

(defmethod value-type ((binding interface-binding))
  (let ((sb (stage-binding binding)))
    (when sb
      (value-type sb))))

(defmethod value-type ((binding generic-type))
  binding)

(defmethod value-type ((binding interface-stage-binding))
  (value-type (binding binding)))



(defun bind-interface (stage type interface-qualifier name
                       &key internal target-name array layout-qualifier)
  (let ((type (or (get-type-binding type) type)))
    (cond
      ((eq name t)
       ;; binding an interface/uniform to T makes all of the slots visible
       ;; as bindings
       (loop for slot in (bindings type)
             for slot-name = (name slot)
             for slot-target-name = (target-name slot)
             for vb = (variable-bindings *environment*)
             do (unless (typep (gethash slot-name vb) 'interface-binding)
                  (setf (gethash slot-name vb)
                        (make-instance 'interface-binding
                                       :internal internal
                                       :name slot-name
                                       :target-name slot-target-name)))
                (setf (getf (stage-bindings (gethash slot-name vb)) stage)
                      (make-instance 'interface-stage-binding
                                     :stage stage
                                     :interface-qualifier interface-qualifier
                                     :binding slot
                                     :interface-block type
                                     :layout-qualifier layout-qualifier))))
      (name
       ;; otherwise if we bind it with a name, make that name visible
       (let ((vb (variable-bindings *environment*)))
         (unless (typep (gethash name vb) 'interface-binding)
           (setf (gethash name vb) (make-instance 'interface-binding
                                                  :name name
                                                  :internal internal
                                                  :target-name target-name
                                                  :array-size array)))
         (setf (getf (stage-bindings (gethash name vb)) stage)
               (make-instance 'interface-stage-binding
                              :stage stage
                              :interface-qualifier interface-qualifier
                              :binding type
                              :array-size array
                              :layout-qualifier layout-qualifier)))))))

(%shader-macro cl-webgpu/shader/internal::interface (%name (&key in out uniform buffer internal
                                               layout)
                                    &body slots)
  ;; in/out/uniform are either T,NAME,or (&key :vertex :fragment ...)
  ;; where T means make slots directly visible in all stages,
  ;; NAME means make aggregate visible as NAME in all stages
  ;; and VERTEX/FRAGMENT/ETC means make aggregate visible with specified name(s)
  ;;   in specified stage(s)
  (let* ((name (if (consp %name) (car %name) %name))
         (env (default-env name))
         (target-name (if (consp %name) (cadr %name)))
         (layout-qualifier (copy-list layout)))
    (check-locked env name)
    (setf (gethash name (types env))
          (make-instance 'interface-type
                         :name name
                         :target-name target-name
                         :internal internal
                         :bindings
                         (loop for (%sname type . args) in slots
                               for sname = (if (consp %sname)
                                               (first %sname)
                                               %sname)
                               for target-sname = (when (consp %sname)
                                                  (second %sname))
                               ;; should these be some 'slot-binding' type?
                               collect (make-instance 'binding
                                                      :name sname
                                                      :target-name target-sname
                                                      :value-type (get-type-binding type)
                                                      :qualifiers
                                                      (if (every 'keywordp args)
                                                          args
                                                          (break "todo: non-qualifier interface slot args? ~s ~s~% ~s" %sname type args))))))
    (loop
      for (k x) on (list :in in :out out :uniform uniform
                         :buffer buffer) by #'cddr
      when (and x (symbolp x))
        ;; possibly should also accept (lisp-name "gl_name") lists?
        ;; don't want (:vertex t ;geometry foo ...) lists here though
        do (bind-interface t name k x :internal internal
                                      :layout-qualifier layout-qualifier)
      else
        when x
          do (loop for (stage %bind) on x by #'cddr
                   for bind = (if (consp %bind) (car %bind) %bind)
                   for target-bind = (if (consp %bind) (cadr %bind) nil)
                   for array = (if (consp %bind) (caddr %bind) nil)
                   do (bind-interface stage name k bind :internal internal
                                                        :target-name target-bind
                                                        :array array
                                                        :layout-qualifier
                                                        layout-qualifier)))
    nil))

(defun in/out/uniform/attrib (qualifier %name type
                              &key location internal stage index layout
                                qualifiers default group binding)
  ;; possibly should have generic '&rest args' instead of enumerating options?
  (let* ((env (default-env %name))
         (vb (variable-bindings env))
         (name (if (consp %name) (car %name) %name))
         (target-name (if (consp %name) (cadr %name)))
         (layout-qualifier (copy-list layout)))
    (unless (typep (gethash name vb) 'interface-binding)
      (check-locked env name)
      (setf (gethash name vb) (make-instance 'interface-binding
                                             :internal internal
                                             :target-name target-name
                                             :name name)))
    ;(assert (equal (target-name (gethash name vb)) target-name))
    (unless (equal (target-name (gethash name vb)) target-name)
      (warn "renaming binding ~s from ~s to ~s~%"
            name (target-name (gethash name vb)) target-name)
      (setf (target-name (gethash name vb)) target-name))
    ;; possibly should just pass the layout qualifiers directly as a plist
    ;; rather than enumerating options here?
    (when location
      (setf (getf layout-qualifier :location) location))
    (when index
      (setf (getf layout-qualifier :index) index))
    (when group
      (setf (getf layout-qualifier :group) group))
    (when binding
      (setf (getf layout-qualifier :binding) binding))
    ;; just treating vs attributes and fs outputs like named interface
    ;; blocks for now
    (let ((old (getf (stage-bindings (gethash name vb)) stage)))
      (unless (and (typep old 'interface-stage-binding)
                   (eql (stage old) stage)
                   (equalp (interface-qualifier old)
                           (cons qualifier qualifiers))
                   (equalp (layout-qualifier old) layout-qualifier)
                   (eql (binding old) (or (get-type-binding type) type))
                   (eql (default old) default))
        (check-locked env name)
        (setf (getf (stage-bindings (gethash name vb)) stage)
              (make-instance 'interface-stage-binding
                             :stage stage
                             :interface-qualifier (cons qualifier qualifiers)
                             :layout-qualifier layout-qualifier
                             :binding (or (get-type-binding type) type)
                             :default default))))))

(%shader-macro cl-webgpu/shader/internal::attribute (%name type &key location internal)
  (in/out/uniform/attrib :attribute %name type :location location :internal internal :stage :vertex)
  nil)

(%shader-macro cl-webgpu/shader/internal::input (%name type &key location (stage t)
                                      internal qualifiers)
  (in/out/uniform/attrib :in %name type
                         :location location :internal internal :stage stage
                         :qualifiers qualifiers)
  nil)

(%shader-macro cl-webgpu/shader/internal::output (%name type &key location (stage t)
                                       internal qualifiers)
  (in/out/uniform/attrib :out %name type
                         :location location :internal internal :stage stage
                         :qualifiers qualifiers)
  nil)

(%shader-macro cl-webgpu/shader/internal::uniform (%name type &key location (stage t)
                                       internal layout qualifiers default
                                       group binding)
  (in/out/uniform/attrib :uniform %name type
                         :location location :internal internal :stage stage
                         :layout layout
                         :qualifiers qualifiers
                         :default default
                         :group group :binding binding)
  nil)

(%shader-macro cl-webgpu/shader/internal::shared (%name type &key (stage t) layout
                                      qualifiers)
  (in/out/uniform/attrib :shared %name type
                         :stage stage
                         :layout layout
                         :qualifiers qualifiers)
  nil)


(%shader-macro cl-webgpu/shader/internal::bind-interface (stage block-name interface-qualifier instance-name)
  (bind-interface stage block-name interface-qualifier instance-name)
  nil)

(defparameter *known-declarations*
  '(declaration dynamic-extent ftype function ignore inline notinline
    optimize special type invariant))
(defparameter *free-declarations*
  '(invariant))

(defmethod process-type-declarations-for-scope (scope)
  (flet ((process-declaration (d a)
           (let ((type (get-type-binding d)))
             (unless type
               (warn "declared unknown type ~a for variables ~a?" d a))
             (loop for var in a
                   for b = (find var (bindings scope) :key 'name)
                   for bt = (unless (and (not b)
                                         (member d *free-declarations*))
                              (if (not b)
                                  ;; todo: possibly should add a constraint
                                  ;; on free but existing bindings?
                                  ;; for now just not allowing them, since
                                  ;; variables are always same type in shaders...
                                  (error "got declaration for free binding ~s?"
                                         var)
                                  (declared-type b)))
                   do (when (not (member bt (list type d t)))
                        (warn "changing type of ~a from ~a to ~a?"
                              var (declared-type b) type))
                      (setf (declared-type b) type))))
         (process-qualifier (d a)
           (loop for var in a
                 for b = (find var (bindings scope) :key 'name)
                 when (not b)
                   do (error "declared unknown variable ~s as ~s?"
                             var d)
                 else
                   do (pushnew d (qualifiers b)))))
    (let ((declarations (declarations scope)))
      (loop for (decl . args) in (mapcan 'cdr declarations)
            do (cond
                 ;; handle explicit (type foo ...) declarations
                 ((eql decl 'type)
                  (process-declaration (car args) (cdr args)))
                 ;; handle 'values' for return type
                 ((eql decl 'values)
                  (unless (typep scope 'global-function)
                    (error "VALUES declaration not handled for ~s yet?"
                           (type-of scope)))
                  (let* ((type-name (if args
                                        (car args)
                                        :void))
                         (type (get-type-binding type-name))
                         (rest-args (cdr args))
                         (location (getf rest-args :location)))
                    (unless type
                      (error "declared unknown return type ~s in VALUES?"
                             type-name))
                    (setf (declared-type scope) type)
                    (when location
                      (setf (return-location scope) location))))
                 ;; 'layout' declarations (for geometry shaders, etc)
                 ;; (layout (:in primitive &rest) (:out prim &rest args) ...)
                 ;; for compute: (:in nil &key local-size-x local-size-y loccal-size-z ...)
                 ((eql decl 'layout)
                  (loop for (car . cdr) in args
                        do (setf (gethash car (layout-qualifiers scope))
                                 ;; store first entry twice so we can treat
                                 ;; whole list relatively uniformly
                                 (cons (car cdr) cdr))))
                 ((eql decl 'stage)
                  (setf (valid-stages scope) args))
                 ((member decl '(in out inout))
                  (process-qualifier decl args))
                 ;; ignore any other known declarations for now
                 ((member decl *known-declarations*)
                  )
                 ;; otherwise try to use it as a type declaration
                 (t
                  (process-declaration decl args))))))
  ;; return the scope, so we can just wrap ceration of an instance
  ;; with this to process the declaration
  scope)


(defun add-concrete-type (name target-name &key (env *environment*) type)
  (setf (gethash name (types env))
        (or type
            (if (symbolp target-name)
                ;; allow aliases to already defined types
                (let ((a (gethash target-name (types env))))
                  (assert a)
                  a)
                (make-instance 'concrete-type
                               :name name
                               :target-name target-name)))))

(let ((*environment* cl-webgpu/shader/internal::*shader-base-environment*))
  (add-concrete-type :void "void")
  (add-concrete-type :bool "bool")
  (add-concrete-type :int "i32")
  (add-concrete-type :int32 :int)
  (add-concrete-type :uint "u32")
  (add-concrete-type :uint32 :uint)
  (add-concrete-type :float "f32")
  (add-concrete-type :float32 :float)
  (add-concrete-type :vec2 "vec2<f32>")
  (add-concrete-type :vec3 "vec3<f32>")
  (add-concrete-type :vec4 "vec4<f32>")
  (add-concrete-type :bvec2 "vec2<bool>")
  (add-concrete-type :bvec3 "vec3<bool>")
  (add-concrete-type :bvec4 "vec4<bool>")
  (add-concrete-type :ivec2 "vec2<i32>")
  (add-concrete-type :ivec3 "vec3<i32>")
  (add-concrete-type :ivec4 "vec4<i32>")
  (add-concrete-type :uvec2 "vec2<u32>")
  (add-concrete-type :uvec3 "vec3<u32>")
  (add-concrete-type :uvec4 "vec4<u32>")

  (add-concrete-type :mat2 "mat2x2<f32>")
  (add-concrete-type :mat3 "mat3x3<f32>")
  (add-concrete-type :mat4 "mat4x4<f32>")
  (add-concrete-type :mat2x2 :mat2) ;; not sure which way these should alias?
  (add-concrete-type :mat2x3 "mat2x3<f32>")
  (add-concrete-type :mat2x4 "mat2x4<f32>")
  (add-concrete-type :mat3x2 "mat3x2<f32>")
  (add-concrete-type :mat3x3 :mat3)
  (add-concrete-type :mat3x4 "mat3x4<f32>")
  (add-concrete-type :mat4x2 "mat4x2<f32>")
  (add-concrete-type :mat4x3 "mat4x3<f32>")
  (add-concrete-type :mat4x4 :mat4)

  (add-concrete-type :sampler-2d "texture_2d<f32>")
  (add-concrete-type :sampler-3d "texture_3d<f32>")
  (add-concrete-type :sampler-cube "texture_cube<f32>")
  (add-concrete-type :sampler-2d-array "texture_2d_array<f32>")
  (add-concrete-type :sampler-2d-shadow "texture_depth_2d")
  (add-concrete-type :sampler-2d-array-shadow "texture_depth_2d_array")
  (add-concrete-type :sampler-cube-shadow "texture_depth_cube")
  (add-concrete-type :sampler-cube-array-shadow "texture_depth_cube_array")

  (add-concrete-type :isampler-2d "texture_2d<i32>")
  (add-concrete-type :isampler-3d "texture_3d<i32>")
  (add-concrete-type :isampler-cube "texture_cube<i32>")
  (add-concrete-type :isampler-2d-array "texture_2d_array<i32>")

  (add-concrete-type :usampler-2d "texture_2d<u32>")
  (add-concrete-type :usampler-3d "texture_3d<u32>")
  (add-concrete-type :usampler-cube "texture_cube<u32>")
  (add-concrete-type :usampler-2d-array "texture_2d_array<u32>")

  ;; Bare sampler type (for separate texture+sampler bindings)
  (add-concrete-type :sampler "sampler"))


;; add implicit casts to types
(let ((*environment* cl-webgpu/shader/internal::*shader-base-environment*))
  (flet ((c (conversions)
           (let ((to (make-hash-table))    ;; types key casts to
                 (from (make-hash-table))) ;; types that can cast to key
             (loop for (from-type . to-types) in conversions
                   do (setf (gethash from-type to) to-types)
                      (loop for x in to-types
                            do (pushnew from-type (gethash x from))))
             (maphash (lambda (k v)
                        (setf (implicit-casts-to (get-type-binding k))
                              (mapcar 'get-type-binding v)))
                      to)
             (maphash (lambda (k v)
                        (setf (implicit-casts-from (get-type-binding  k))
                              (mapcar 'get-type-binding v)))
                      from))))
    (macrolet ((add-implicit-conversions (&rest conversions)
                 `(c ',conversions)))
      (add-implicit-conversions
       (:int :uint :float)
       (:uint :float)

       (:ivec2 :uvec2 :vec2)
       (:ivec3 :uvec3 :vec3)
       (:ivec4 :uvec4 :vec4)

       (:uvec2 :vec2)
       (:uvec3 :vec3)
       (:uvec4 :vec4)))))

;;; add explicit casts to types
(let ((*environment* cl-webgpu/shader/internal::*shader-base-environment*))
  (flet ((c (&rest types)
           (loop for type in types
                 do (setf (explicit-casts (get-type-binding type))
                          (mapcar 'get-type-binding
                                  (remove type types))))))
    (macrolet ((add-explicit-conversions (&rest conversions)
                 `(progn
                    ,@(mapcar (lambda (a) (cons 'c a))
                              conversions))))
      (add-explicit-conversions
       ;; scalar types
       (:bool :int :uint :float)
       ;; non-scalar types with same number of elements
       (:bvec2 :ivec2 :uvec2 :vec2) ;; 2
       (:bvec3 :ivec3 :uvec3 :vec3) ;; 3
       (:bvec4 :ivec4 :uvec4 :vec4 :mat2) ;; 4
       (:mat2x3 :mat3x2) ;; 6
       (:mat2x4 :mat4x2) ;; 8
       (:mat3) ;; 9
       (:mat3x4 :mat4x3) ;; 12
       (:mat4))))) ;; 16

;;; add scalar/vector set/size to types
(let ((*environment* cl-webgpu/shader/internal::*shader-base-environment*))
  (flet ((c (&rest types)
           (loop with set = (coerce (cons nil (mapcar 'get-type-binding types)) 'vector)
                 for i from 0
                 for type across set
                 when type
                   do (setf (scalar/vector-size type) i
                            (scalar/vector-set type) set
                            (base-type type) (get-type-binding
                                              (first types))))))
    (macrolet ((add-explicit-conversions (&rest conversions)
                 `(progn
                    ,@(mapcar (lambda (a) (cons 'c a))
                              conversions))))
      (add-explicit-conversions
       (:bool :bvec2 :bvec3 :bvec4)
       (:int :ivec2 :ivec3 :ivec4)
       (:uint :uvec2 :uvec3 :uvec4)
       (:float :vec2 :vec3 :vec4)))))

;; add sizes and base type for matrix types
(let ((*environment* cl-webgpu/shader/internal::*shader-base-environment*))
  (loop for f in '(:mat2 :mat2x3 :mat2x4
                   :mat3x2 :mat3 :mat3x4
                   :mat4x2 :mat4x3 :mat4)
        for fb in '(:vec2 :vec3 :vec4
                    :vec2 :vec3 :vec4
                    :vec2 :vec3 :vec4)
        for c in '(4 6 8 6 9 12 8 12 16)
        do (setf (scalar/vector-size (get-type-binding f)) c)
           (setf (base-type (get-type-binding f)) (get-type-binding fb))))
