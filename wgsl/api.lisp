(in-package #:cl-webgpu/shader)

;; calling generate-stage while compile-form is running might see an
;; inconsistent stage, and is reasonably likely when compiling a whole
;; file if calling code doesn't wait a while before calling
;; generate-stage. Doesn't seem to be any reaonable way to determine
;; how long to wait, so adding a lock so at worst we just get
;; redundant shader recompiles instead of errors.
(defparameter *compiler-lock* (bordeaux-threads:make-lock
                               "cl-webgpu/shader:compile-form"))

(defvar *modified-function-hook* nil
  "list of functions to call when shader functions are
modified. Passed a list of names of functions that have been
modified.  May be called multiple times for same function if a whole
file using the cl-webgpu/shader/internal:defun macro is recompiled, so probably should
store names and only update shader programs at next frame rather
than updating programs directly from hook function.")

;; compiler entry points

;; first pass of compilation for one or more forms
;; (expand macros, partial type inference, update dependencies, etc)
(defun compile-form (form)
  "Run first passes of compilation on specified form. (Wrap with PROGN
to process multiple forms). Calls functions in
*MODIFIED-FUNCTION-HOOK* with names of any functions whose definitions
are possibly affected by compiling FORM (for example functions that
call a function defined/updated by FORM, and the (re)defined function
itself). "
  (let ((modified-function-names nil))
    (bordeaux-threads:with-lock-held (*compiler-lock*)
      (cl-webgpu/shader/internal::with-package-environment ()
        (let ((*new-function-definitions* nil)
              (*new-type-definitions* nil)
              (*new-global-definitions* nil))
          ;; 'compile' forms
          (walk form (make-instance 'extract-functions))
          ;; update dependencies for any (re)defined functions
          (loop for f in *new-function-definitions*
                do (update-dependencies f))
          (loop for (nil f) in *new-global-definitions*
                do (update-dependencies f))
          ;; if any functions' lambda list was changed, recompile any
          ;; calls to those functions in their dependents
          (let* ((changed-signatures (remove-if-not #'function-signature-changed
                                                    *new-function-definitions*))
                 (deps (make-hash-table))
                 (update-calls (make-instance 'update-calls
                                              :modified
                                              (alexandria:alist-hash-table
                                               (mapcar (lambda (a)
                                                         (cons a nil))
                                                       changed-signatures)))))
            (loop for i in changed-signatures
                  do (maphash (lambda (k v) (setf (gethash k deps) v))
                              (bindings-using i))
                     (setf (old-lambda-list i)
                           (lambda-list i)))
            (maphash (lambda (k v)
                       (declare (ignore v))
                       (walk k update-calls))
                     deps))
          (let ((modified-deps (make-hash-table)))
            (loop for (nil i) in *new-type-definitions*
                  for deps = (bindings-using i)
                  do (loop for i being the hash-keys of deps
                           when (typep i 'global-function)
                             do (setf (gethash i modified-deps) t)))
            (loop for (nil i) in *new-global-definitions*
                  for deps = (bindings-using i)
                  do (loop for i being the hash-keys of deps
                           when (typep i 'global-function)
                             do (setf (gethash i modified-deps) t)))
            (loop for i in *new-function-definitions*
                  do (setf (gethash i modified-deps) t))
            (when *verbose*
              (format t "deps = ~s~%" (mapcar 'name (alexandria:hash-table-keys modified-deps))))
            (when (plusp (hash-table-count modified-deps))
              (let ((modified (infer-modified-functions
                               (alexandria:hash-table-keys modified-deps))))
                (assert modified)
                (loop for f in modified
                      do (pushnew (name f) modified-function-names)))))

          (when *verbose*
            (format t "modified functions: ~s~%" modified-function-names)
            (format t "modified types: ~s~%" *new-type-definitions*)
            (format t "modified globals: ~s~%" *new-global-definitions*)))))
    ;; call hook outside lock in case it tries to call generate-stage
    (map nil (lambda (a) (funcall a modified-function-names))
         *modified-function-hook*)
    nil))

(defparameter *shader-type->stage*
  (alexandria:plist-hash-table
   '(:vertex-shader :vertex
     :fragment-shader :fragment
     :geometry-shader :geometry
     :tess-control-shader :tess-control)))

(defmethod expand-uniform-slots (prefix (b binding))
  (append (expand-uniform-slots prefix (value-type b))))

(defmethod expand-uniform-slots (prefix (type struct-type))
     (loop for slot in (bindings type)
           for slot-name = (name slot)
           for slot-type = (value-type slot)
           append (expand-uniform-slots (cons slot-name prefix) slot-type)))

(defmethod expand-uniform-slots (prefix (type concrete-type))
  (list (reverse prefix)))

(defmethod expand-uniform-slots (prefix (type array-type))
  (let ((size (array-size type)))
    (etypecase size
      (number
       (loop for i below size
             append (expand-uniform-slots (cons i prefix) (base-type type))))
      (constant-binding
       (unless (numberp (initial-value-form size))
         (error "can't expand constant ~s = ~s when generating uniforms"
                (name size) (initial-value-form size)))
       (loop for i below (initial-value-form size)
             append (expand-uniform-slots (cons i prefix) (base-type type))))
      ((eql :*)
       (cons '[] prefix)))))


(defun expand-uniforms (uniforms expand)
  (loop for u in uniforms
        for sb = (stage-binding u)
        for b = (binding sb)
        collect (list* (name u) (translate-name u)
                       (name (if (typep b 'binding)
                                 (value-type b)
                                 b))
                       (when expand
                         (list :components
                               (expand-uniform-slots (list (name u))
                                                     (binding sb)))))))

(defun expand-buffers (buffers)
  (let ((blocks (delete-duplicates
                 (loop for b in buffers
                       collect (stage-binding b))
                 :test 'equalp
                 :key 'interface-block)))
    (loop for block in blocks
          for ib = (interface-block block)
          for lq = (layout-qualifier block)
          collect (list* (name ib)
                         (translate-name ib)
                         (list :layout lq
                               :components
                               (when ib
                                (loop for b in (bindings ib)
                                      collect (list (name b)
                                                    (name (if (typep b 'binding)
                                                              (value-type b)
                                                              b))))))))))

(defun expand-structs (structs)
  (loop for struct in structs
        collect (list* (name struct)
                       (translate-name struct)
                       (list :components
                             (loop for b in (bindings struct)
                                   collect (list (name b)
                                                 (name (if (typep b 'binding)
                                                           (value-type b)
                                                           b))))))))

;; final pass of compilation
;; finish type inference for concrete types, generate WGSL
(defun generate-stage (stage main &key (expand-uniforms) (preamble nil))
  "Generate WGSL shader for specified STAGE, using function named by
MAIN as the entry point. MAIN and all functions/variables/etc it
depends on should already have been successfully compiled with
COMPILE-FORM. STAGE is :VERTEX, :FRAGMENT, or :COMPUTE.

When PREAMBLE is true, a standard uniform preamble is emitted at
group(0). Defaults to NIL.

Returns the WGSL source string as the primary value.
Second value: list of active uniforms in the form
  (LISP-NAME \"wgslName\" type . PROPERTIES).
Third value: list of active attributes in same format.

For uniforms, PROPERTIES is a plist containing 0 or more of:

:COMPONENTS : (when EXPAND-UNIFORMS is true) for composite
uniforms (structs, etc), a list containing a list of uniform name and
slot names or array indices for each leaf uniform."
  (setf stage (gethash stage *shader-type->stage* stage))
  (bordeaux-threads:with-lock-held (*compiler-lock*)
    (cl-webgpu/shader/internal::with-package-environment (main)
      (let* ((*emit-ugly-preamble* preamble)
             (*print-as-main* (get-function-binding main))
             (*current-shader-stage* stage)
             (uniforms)
             (buffers)
             (attributes)
             (structs))
        (let ((shaken (tree-shaker main)))
          (let ((inferred-types
                  (finalize-inference (get-function-binding main))))
            (loop for s in shaken
                  for i = (when (typep s 'interface-binding)
                            (stage-binding s))
                  when (typep s 'struct-type)
                    do (push s structs)
                  when i
                    do (case (if (consp (interface-qualifier i))
                              (car (interface-qualifier i))
                              (interface-qualifier i))
                         (:uniform
                          (pushnew s uniforms :test 'equal))
                         (:buffer
                          (pushnew s buffers :test 'equal))
                         (:in
                          (when (eq stage :vertex)
                            (pushnew (list (name s) (translate-name s)
                                           (name (binding i)))
                                     attributes :test 'equal)))))
            (values
             (generate-wgsl shaken inferred-types)
             (expand-uniforms uniforms expand-uniforms)
             attributes
             (expand-buffers buffers)
             (expand-structs structs))))))))




(defun struct-fields (struct-name)
  "Return an ordered list of (NAME TYPE-KEYWORD LOCATION BUILTIN) for a DSL struct
registered under STRUCT-NAME, in declaration order.
LOCATION and BUILTIN are NIL for un-annotated (plain) fields.

STRUCT-NAME must be a symbol whose home package contains the struct definition
(i.e. the package that was current when DEFSTRUCT was evaluated).  For structs
defined via the cl-webgpu/shader/cl package (e.g. in a package that :use-s it),
pass the symbol as interned in that user package."
  (bordeaux-threads:with-lock-held (*compiler-lock*)
    (cl-webgpu/shader/internal::with-package-environment (struct-name)
      (let ((st (get-type-binding struct-name)))
        (unless st
          (error "No DSL struct named ~s found in environment for package ~s"
                 struct-name (symbol-package struct-name)))
        (loop for b in (bindings st)
              collect (list (name b)
                            (name (value-type b))
                            (when (typep b 'annotated-binding) (binding-location b))
                            (when (typep b 'annotated-binding) (binding-builtin b))))))))

(defun generate-shader (&key vertex fragment compute (expand-uniform-slots nil) (preamble nil))
  "Generate a single WGSL string with all specified stages.
VERTEX, FRAGMENT, and COMPUTE are symbols naming entry point functions.
When PREAMBLE is true, a standard uniform preamble is emitted at group(0).
Defaults to NIL. Returns the combined WGSL source string as the primary value."
  (bordeaux-threads:with-lock-held (*compiler-lock*)
    (let ((*emit-ugly-preamble* preamble)
          (stages nil)
          (all-uniforms nil)
          (all-attributes nil))
      ;; Process each stage
      (flet ((process-stage (stage main)
               (when main
                 (cl-webgpu/shader/internal::with-package-environment (main)
                   (let* ((*print-as-main* (get-function-binding main))
                          (*current-shader-stage* stage)
                          (shaken (tree-shaker main))
                          (inferred-types (finalize-inference (get-function-binding main)))
                          (uniforms nil)
                          (attributes nil))
                     (loop for s in shaken
                           for i = (when (typep s 'interface-binding)
                                     (stage-binding s))
                           when i
                             do (case (if (consp (interface-qualifier i))
                                       (car (interface-qualifier i))
                                       (interface-qualifier i))
                                  (:uniform (pushnew s uniforms :test 'equal))
                                  (:in (when (eq stage :vertex)
                                         (pushnew (list (name s) (translate-name s)
                                                        (name (binding i)))
                                                  attributes :test 'equal)))))
                     (push (list stage shaken inferred-types *print-as-main*) stages)
                     (setf all-uniforms (append all-uniforms
                                               (expand-uniforms uniforms expand-uniform-slots)))
                     (setf all-attributes (append all-attributes attributes)))))))
        (process-stage :vertex vertex)
        (process-stage :fragment fragment)
        (process-stage :compute compute))
      (values
       (let ((*environment* cl-webgpu/shader/internal::*shader-base-environment*)
             (*global-environment* cl-webgpu/shader/internal::*shader-base-environment*))
         (generate-wgsl-combined (nreverse stages)))
       all-uniforms
       all-attributes))))

(in-package #:cl-webgpu/shader/internal)
;;; CL macros for the shader API (for use with slime when working on files
;;;  to be loaded as shader code)

(cl:defmacro defun (name args &body body)
  `(cl-webgpu/shader::compile-form '(cl:defun ,name ,args ,@body)))

(cl:defmacro defmacro (name args &body body)
  `(cl-webgpu/shader::compile-form '(cl:defmacro ,name ,args ,@body)))

(cl:defmacro defconstant (name value type)
  `(cl-webgpu/shader::compile-form '(%defconstant ,name ,value ,type)))

(cl:defmacro defstruct (name &rest slots)
  `(cl-webgpu/shader::compile-form '(cl:defstruct ,name ,@slots)))

(cl:defmacro interface (name (&rest args &key in out uniform buffer
                                           layout)
                        &body slots)
  (declare (ignore in out uniform buffer layout))
  `(cl-webgpu/shader::compile-form '(interface ,name ,args ,@slots)))

(cl:defmacro attribute (name type &rest args &key location)
  (declare (ignore location))
  `(cl-webgpu/shader::compile-form '(attribute ,name ,type ,@args)))

(cl:defmacro input (name type &rest args &key  stage location qualifiers)
  (declare (ignore location stage))
  `(cl-webgpu/shader::compile-form '(input ,name ,type ,@args)))

(cl:defmacro output (name type &rest args &key stage location qualifiers)
  (declare (ignore location stage))
  `(cl-webgpu/shader::compile-form '(output ,name ,type ,@args)))

(cl:defmacro uniform (name type &rest args &key  stage location internal layout
                                             qualifiers default group binding
                      &allow-other-keys)
  (declare (ignore location stage internal layout qualifiers default group binding))
  `(cl-webgpu/shader::compile-form '(uniform ,name ,type ,@args)))

(cl:defmacro shared (name type &rest args &key  stage layout qualifiers
                     &allow-other-keys)
  (declare (ignore stage layout qualifiers))
  `(cl-webgpu/shader::compile-form '(shared ,name ,type ,@args)))

(cl:defmacro bind-interface (stage block-name interface-qualifier instance-name)
  `(cl-webgpu/shader::compile-form '(bind-interface ,stage ,block-name
                                 ,interface-qualifier ,instance-name)))

;;; shader versions for use when whole file is processed directly
(%shader-macro defun (name args &body body)
  `(cl:defun ,name ,args ,@body))



;; define cl:position as a vec4 vertex attribute at location 0, since
;; it is pretty common but can't be defined from user code with CL
;; package locked
(cl-webgpu/shader/internal::shader-input position :vec4 :location 0)
;; and single-float pi as well
(cl-webgpu/shader/internal::shader-defconstant pi #.(float pi 1.0) :float)

;; lock CL and shader packages, so user packages can't define
;; conflicting globals with names in those packages
(setf (cl-webgpu/shader::locked cl-webgpu/shader::*cl-environment*) t
      (cl-webgpu/shader::locked cl-webgpu/shader/internal::*shader-base-environment*) t)
