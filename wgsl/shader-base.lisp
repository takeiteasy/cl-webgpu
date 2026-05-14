(in-package #:cl-webgpu/shader/internal)

;;; definitions for CL macros supported by the shader DSL
;;;   (and maybe some extra utilities)


(defclass shader-walker (cl-webgpu/shader::cl-walker)
  ())

(defparameter *current-function* nil
  "current function being compiled if any")


#++
(let ((a nil))
  (do-external-symbols (s (find-package :cl)
                          (sort a 'string<))
    (when (and (fboundp s) (not (special-operator-p s))
               (macro-function s))
      (push s a))))

;;; stuff that is (or at least could be) handled by compiler:
;;;   all args are (potentially) evaluated normally, etc
;;; AND, DECF, INCF, OR,

;;; not implementing (either not meaningful/useful or too hard)
;;;   (clos, runtime exceptions, etc)
(loop for s in
      '(CALL-METHOD ASSERT CCASE CTYPECASE DEFCLASS DEFGENERIC
        DEFINE-CONDITION DEFINE-METHOD-COMBINATION DEFMETHOD
        DEFPACKAGE DESTRUCTURING-BIND DO-ALL-SYMBOLS
        DO-EXTERNAL-SYMBOLS DO-SYMBOLS ECASE ETYPECASE FORMATTER
        HANDLER-BIND HANDLER-CASE IGNORE-ERRORS IN-PACKAGE
        MULTIPLE-VALUE-BIND MULTIPLE-VALUE-LIST MULTIPLE-VALUE-SETQ
        NTH-VALUE PPRINT-EXIT-IF-LIST-EXHAUSTED PPRINT-LOGICAL-BLOCK
        PPRINT-POP PRINT-UNREADABLE-OBJECT PROG PROG* PUSHNEW
        RESTART-BIND RESTART-CASE TIME TRACE UNTRACE
        WITH-CONDITION-RESTARTS WITH-HASH-TABLE-ITERATOR
        WITH-COMPILATION-UNIT WITH-INPUT-FROM-STRING WITH-OPEN-FILE
        WITH-OPEN-STREAM WITH-OUTPUT-TO-STRING WITH-PACKAGE-ITERATOR
        WITH-SIMPLE-RESTART WITH-STANDARD-IO-SYNTAX)
      do (cl-webgpu/shader::add-macro
          s
          `(lambda (&rest r)
             (declare (ignore r))
             (error ,(format nil "~a not supported in shader DSL" s)))
          :env *shader-base-environment*))

;;; not sure if we will have some 'list' equivalent?
(loop for s in
      '(POP DOLIST PUSH REMF)
      do (cl-webgpu/shader::add-macro
          s
          `(lambda (&rest r)
             (declare (ignore r))
             (error ,(format nil "~a not supported in shader DSL" s)))
          :env *shader-base-environment*))


;;; maybe?
(loop for s in
      '(DECLAIM CHECK-TYPE DEFTYPE DEFINE-SETF-EXPANDER DEFSETF LAMBDA TYPECASE
        WITH-ACCESSORS WITH-SLOTS)
      do (cl-webgpu/shader::add-macro
          s
          `(lambda (&rest r)
             (declare (ignore r))
             (error ,(format nil "~a not supported in shader DSL (yet?)" s)))
          :env *shader-base-environment*))

;;; todo:

(%shader-macro case (form &body body)
  (flet ((numeric-constant (s)
           (typecase s
             (number s)
             ;; accepting constants even though CL CASE doesn't, since
             ;; that is annoying
             (symbol
              (let ((v (cl-webgpu/shader::get-variable-binding s)))
                (and v
                     ;; todo: factor this stuff out
                     (typep v 'cl-webgpu/shader::constant-binding)
                     (typep (cl-webgpu/shader::value-type v)
                            'cl-webgpu/shader::concrete-type)
                     (member (cl-webgpu/shader::name
                              (cl-webgpu/shader::value-type v))
                             ;; WGSL `switch` takes integers, so
                             ;; limiting to that even though we
                             ;; currently expand to nested IF which
                             ;; could take floats too
                             '(:int :int8 :int16 :int32 :int64
                               :uint :uint8 :uint16 :uint32 :uint64)))))
             (t s))))
    (loop for (case) in body
          do (assert (or (numeric-constant case)
                         (eql case t)
                         (and (consp case) (every #'numeric-constant case)))))
    (labels ((c (x)
               (etypecase x
                 (cons `(or ,@(loop for v in x collect `(= ,form ,v))))
                 (number `(= ,form ,x))
                 (symbol
                  (assert (numeric-constant x))
                  `(= ,form ,x))))
             (r (b)
               (let ((a (first b)))
                 (if (eql (first a) t)
                     `(progn ,@(rest a))
                     `(if ,(c (first a))
                          (progn ,@(rest a))
                          ,@ (when (rest b)
                               (list (r (rest b)))))))))
      (r body))))


(%shader-macro cond (&body body)
  (if (eq (caar body) t)
      `(progn ,@(cdar body))
      `(if ,(caar body)
           (progn ,@(cdar body))
           ,@(when (cdr body)
               `((cond ,@(cdr body)))))))


(%shader-macro define-compiler-macro (name lambda-list &body body)
  ;; fixme: extract docstrings/declarations from body
  (cl-webgpu/shader::add-compiler-macro name
                                    `(lambda (form env)
                                       (declare (ignore env))
                                       (destructuring-bind ,lambda-list
                                           (cdr form)
                                         ,@body)))
  nil)


(%shader-macro define-modify-macro (&body body)
  (declare (ignore body))
  `(error "DEFINE-MODIFY-MACRO not implemented yet for shader DSL"))

(%shader-macro define-symbol-macro (name expansion)
  (cl-webgpu/shader::add-symbol-macro name expansion)
  nil)

(%shader-macro cl:defmacro (name lambda-list &body body)
  ;; fixme: extract docstrings/declarations from body
  #++(format t "define macro ~s~%" name)
  (cl-webgpu/shader::add-macro name
                           `(lambda (form env)
                              (declare (ignore env))
                              (destructuring-bind ,lambda-list
                                  (cdr form)
                                ,@body)))
  nil)


;;; no 'unbound' variables in shaders, so requiring value arg, and
;;; not sure there is any distinction between DEFVAR and DEFPARAMETER
;;; in shaders, so just expanding to defparameter...
(%shader-macro defvar (name value &optional docs)
  (declare (ignore docs))
  `(defparameter ,name ,value))

(%shader-macro do (&body body)
  (declare (ignore body))
  `(error "DO not implemented yet for shader DSL"))

(%shader-macro do* (&body body)
  (declare (ignore body))
  `(error "DO* not implemented yet for shader DSL"))

(%shader-macro dotimes ((var count &optional (result nil)) &body body)
  (if result
      `(error "RESULT not implemented for shader DSL DOTIMES yet")
      `(let ((,var 0))
         (declare (:int ,var))
         (%for (nil ((< ,var ,count)) ((incf ,var)))
               ,@body))))

(%shader-macro dotimes/u ((var count &optional (result nil)) &body body)
  (if result
      `(error "RESULT not implemented for shader DSL DOTIMES/U yet")
      `(let ((,var (uint 0)))
         (declare (:uint ,var))
         (%for (nil ((< ,var ,count)) ((incf ,var)))
               ,@body))))

(%shader-macro loop (&body body)
  (declare (ignore body))
  `(error "LOOP not implemented yet for shader DSL"))

(%shader-macro loop-finish (&body body)
  (declare (ignore body))
  `(error "LOOP-FINISH not implemented yet for shader DSL"))

(%shader-macro prog1 (first-form &body form*)
  (alexandria:with-gensyms (temp)
    `(let ((,temp ,first-form))
       ,@form*
       ,temp)))

(%shader-macro prog2 (first-form second-form &rest form*)
  (alexandria:with-gensyms (temp)
    `(progn
       ,first-form
       (let ((,temp ,second-form))
         ,@form*
         ,temp))))

(%shader-macro PSETF (&body body)
  (error "PSETF not implemented yet for shader DSL")
  `(,@body))

(%shader-macro PSETQ (&body body)
  (error "PSETQ not implemented yet for shader DSL")
  `(,@body))

;; handle by compiler for now?
#++
(%shader-macro return (&body body)
 `(,@body))

(%shader-macro rotatef (&body args)
  (when (cdr args) ;; ignore it if 1 or fewer places
    (alexandria:with-gensyms (temp)
      `(let ((,temp ,(car args)))
         ,@(loop for (a . b) on args
                 while b
                 collect `(setf ,a ,(car b)))
         (setf ,(car (last args)) ,temp)
         ;; rotatef returns NIL
         nil))))

(%shader-macro setf (&body pairs)
  ;; for now, just expand to a bunch of SETQ forms and hope the
  ;; compiler can deal with them
  ;; (probably implementing things like swizzles and maybe struct
  ;;  accesse at that level, so should be enough for a while, but
  ;;  will probably eventually want to be able to do stuff like
  ;;  (setf (ldb...) foo) etc.)
  (if (> (length pairs) 2)
      `(progn ,@(loop for (a b) on pairs by #'cddr
                      collect `(setq ,a ,b)))
      `(setq ,(first pairs) ,(second pairs))))

(%shader-macro shiftf (&rest args)
  (alexandria:with-gensyms (temp)
    `(let ((,temp ,(car args)))
       ,@(loop for (a . b) on args
               while b
               collect `(setf ,a ,(car b)))
       ,temp)))


(%shader-macro incf (x &optional (inc 1))
  `(setf ,x (+ ,x ,inc)))

(%shader-macro unless (a &rest b)
  ;; not quite usual expansion, since we don't really have a "NIL" to return
  `(if (not ,a) (progn ,@b)))

(%shader-macro when (a &rest b)
  `(if ,a (progn ,@b)))

;;; translate into IR

(cl:defun filter-progn (x)
  (loop for i in x
        ;; if we have a progn in the body, just expand the contents
        ;; (but not something with progn as a mixin)
        when (eq (class-of i) (find-class 'cl-webgpu/shader::progn-body))
          append (filter-progn (cl-webgpu/shader::body i))
        else
          if i
            collect i))

(cl-webgpu/shader::defwalker shader-walker (defparameter name value &optional docs)
  (declare (ignore docs))
  (cl-webgpu/shader::add-variable name (cl-webgpu/shader::@ value)
                              :type 'cl-webgpu/shader::global-variable))

(cl-webgpu/shader::defwalker shader-walker (cl:defconstant name value &optional docs)
  (declare (ignore docs))
  (cl-webgpu/shader::add-variable name
                              (cl-webgpu/shader::@ value)
                              :type 'cl-webgpu/shader::constant-binding))

(cl-webgpu/shader::defwalker shader-walker (%defconstant name value type)
  (cl-webgpu/shader::add-variable name
                              (cl-webgpu/shader::@ value)
                              :type 'cl-webgpu/shader::constant-binding
                              :value-type type))

#++
(cl-webgpu/shader::defwalker shader-walker (cl:defun name lambda-list &body body+d)
  (cl-webgpu/shader::process-type-declarations-for-scope
   (multiple-value-bind (body declare doc)
       (alexandria:parse-body body+d :documentation t)
     (cl-webgpu/shader::add-function name lambda-list
                                 (filter-progn (cl-webgpu/shader::@@ body))
                                 :declarations declare :docs doc))))

(cl-webgpu/shader::defwalker shader-walker (let (&rest bindings) &rest body+d)
  (let ((previous (make-hash-table)))
    (cl-webgpu/shader::process-type-declarations-for-scope
     (multiple-value-bind (body declare)
         (alexandria:parse-body body+d)
       (let ((l (make-instance
                 'cl-webgpu/shader::binding-scope
                 :bindings (loop for (n i) in bindings
                                 do (setf (gethash n previous) t)
                                 collect (make-instance
                                          'cl-webgpu/shader::local-variable
                                          :name n
                                          :init (let ((cl-webgpu/shader::*check-conflict-vars* previous))
                                                  (cl-webgpu/shader::@ i))
                                          :value-type t))
                 :declarations declare
                 :body nil)))
         (loop for (n i) in bindings
               for b in (cl-webgpu/shader::bindings l)
               when (eq (gethash n previous) :conflict)
                 do (setf (cl-webgpu/shader::conflicts b) t))
         (setf (cl-webgpu/shader::body l)
               (cl-webgpu/shader::with-lambda-list-vars (l)
                 (cl-webgpu/shader::@@ body)))
         l)))))

(cl-webgpu/shader::defwalker shader-walker (let* (&rest bindings) &rest body+d)
  (multiple-value-bind (body declare)
      (alexandria:parse-body body+d)
    (cl-webgpu/shader::process-type-declarations-for-scope
     (cl-webgpu/shader::with-environment-scope ()
       (make-instance
        'cl-webgpu/shader::binding-scope
        :bindings (loop for (n i) in bindings
                        for b = (make-instance
                                 'cl-webgpu/shader::local-variable
                                 :name n
                                 :init (cl-webgpu/shader::@ i)
                                 :value-type t)
                        collect b
                        do (cl-webgpu/shader::add-variable n i :binding b))
        :declarations declare
        :body (cl-webgpu/shader::@@ body))))))

(cl-webgpu/shader::defwalker shader-walker (progn &body body)
  (make-instance 'cl-webgpu/shader::explicit-progn
                 :body (filter-progn (cl-webgpu/shader::@@ body))))

(cl-webgpu/shader::defwalker shader-walker (setq &rest assignments)
  (cond
    ;; if we have multiple assignments, expand to a sequence of 2 arg setq
    ((> (length assignments) 2)
     (cl-webgpu/shader::walk `(progn ,@(loop for (a b) on assignments by #'cddr
                                         collect `(setq a b)))
                         cl-webgpu/shader::walker))
    ;; single assignment
    ((= (length assignments) 2)
     (let* ((binding (cl-webgpu/shader::@ (first assignments)))
            (value (second assignments)))
       (assert (typep binding 'cl-webgpu/shader::place))
       (make-instance 'cl-webgpu/shader::variable-write
                      :binding binding
                      :value (cl-webgpu/shader::@ value))))
    (t (error "not enough arguments for SETQ in ~s?" assignments))))

(cl-webgpu/shader::defwalker shader-walker (if a b &optional c)
  (make-instance 'cl-webgpu/shader::if-form
                 :test (cl-webgpu/shader::@ a)
                 :then (cl-webgpu/shader::@ b)
                 :else (cl-webgpu/shader::@ c)))

(cl-webgpu/shader::defwalker shader-walker (%for (init while step) &body body)
  (make-instance 'cl-webgpu/shader::for-loop
                 :init (mapcar #'cl-webgpu/shader::@ init)
                 :while (mapcar #'cl-webgpu/shader::@ while)
                 :step (mapcar #'cl-webgpu/shader::@ step)
                 :body (cl-webgpu/shader::@@ body)))


;; function application
(defmethod cl-webgpu/shader::walk-cons (car cdr (walker shader-walker))
  ;; should have already expanded macros/local functions by now,
  ;; so anything left is a function call of some sort
  ;; we also handle a few special cases here for now:
  ;;  symbols starting with #\. are treated as struct slot accessors/swizzle
  ;;  aref forms are converted specially
  (let ((binding (cl-webgpu/shader::get-function-binding car))
        (macro (cl-webgpu/shader::get-macro-function car))
        (cmacro (cl-webgpu/shader::get-compiler-macro-function car)))
    (flet ((add-dependencies (called)
             called))
      (cond
        ((and cmacro
              (let* ((form (list* car cdr))
                     (expanded (funcall cmacro form
                                        cl-webgpu/shader::*environment*)))
                (if (eq expanded form)
                    nil
                    (cl-webgpu/shader::walk expanded walker)))))
        (macro
         (cl-webgpu/shader::walk (funcall macro (list* car cdr)
                                      cl-webgpu/shader::*environment*)
                             walker))
        ((typep binding 'cl-webgpu/shader::function-binding-function)
         (add-dependencies binding)
         (make-instance 'cl-webgpu/shader::function-call
                        :function binding
                        :raw-arguments cdr
                        :argument-environment cl-webgpu/shader::*environment*
                        :arguments (mapcar (lambda (x)
                                             (cl-webgpu/shader::walk x walker))
                                           (funcall (cl-webgpu/shader::expander binding)
                                                    cdr))))
        ((eq car 'aref)
         (make-instance 'cl-webgpu/shader::array-access
                        :binding (cl-webgpu/shader::walk (first cdr) walker)
                        :index (cl-webgpu/shader::walk (second cdr) walker)))
        ((eq car 'vector)
         ;; todo: fix type inference/dependency tracking so we can get
         ;; rid of this
         (unless (every 'atom cdr)
           (error "can't handle function calls in array initialization yet"))
         (make-instance 'cl-webgpu/shader::array-initialization
                        :raw-arguments cdr
                        :argument-environment cl-webgpu/shader::*environment*
                        :arguments (mapcar (lambda (x)
                                             (cl-webgpu/shader::walk x walker))
                                           cdr)
                        :base-type t
                        :array-size (length cdr)
                        :name (if (< (length cdr) 16)
                                  (cons car cdr)
                                  'vector)))
        ;; not sure about syntax for slot/swizzle, for now
        ;; using (@ struct slot) or (slot-value struct 'slot) for slot access
        ;; and (.xyz vec) for swizzle
        ((or (eq car '@)
             (and (eq car 'slot-value)
                  (eq (caadr cdr) 'quote)))
         (make-instance 'cl-webgpu/shader::slot-access
                        :binding (cl-webgpu/shader::walk (first cdr) walker)
                        :field (if (consp (second cdr))
                                   (second (second cdr))
                                   (second cdr))))
        ((and (symbolp car)
              (char= (char (symbol-name car) 0) #\.)
              ;; fixme: do this more efficiently
              ;; swizzle should look like .AAAA where AAAA is up to 4
              ;; characters from either XYZW, RGBA, or STPQ
              ;; (repeats allowed)
              (= 1 (count #\. (symbol-name car) :test #'char=))
              (<= 2 (length (symbol-name car)) 5)
              (or (every (lambda (a) (position a ".XYZW" :test #'char=))
                         (symbol-name car))
                  (every (lambda (a) (position a ".RGBA" :test #'char=))
                         (symbol-name car))
                  (every (lambda (a) (position a ".STPQ" :test #'char=))
                         (symbol-name car))))
         (make-instance 'cl-webgpu/shader::swizzle-access
                        :binding (cl-webgpu/shader::walk (first cdr) walker)
                        :field (subseq (string car) 1)
                        :min-size (loop for i from 1 below (length (string car))
                                        for c = (aref (string car) i)
                                        maximize (or (position c "RGBA")
                                                     (position c "XYZW")
                                                     (position c "STPQ")))))
        ((symbolp car)
         (make-instance 'cl-webgpu/shader::function-call
                        :function (add-dependencies
                                   (cl-webgpu/shader::add-unknown-function car))
                        :raw-arguments cdr
                        :argument-environment cl-webgpu/shader::*environment*
                        :arguments nil))
        (t
         (call-next-method))))))

;; struct construction via (make type-name)
(cl-webgpu/shader::defwalker shader-walker (make type-name)
  (let ((type (cl-webgpu/shader::get-type-binding type-name)))
    (unless (typep type 'cl-webgpu/shader::struct-type)
      (error "MAKE requires a struct type, got ~s" type-name))
    (make-instance 'cl-webgpu/shader::struct-construction
                   :struct-type type
                   :value-type type)))

;; literals and variable access
(defmethod cl-webgpu/shader::walk (form (walker shader-walker))
  ;; symbol macros should already be expanded, so nothing left but
  ;; literals, variables and constants
  ;; (would be nice to expand constants inline, but we might not
  ;;  know the actual value yet, and the form used to initialize the constant
  ;;  might be expensive to evaluate repeatedly)
  ;; NIL = false literal, T = true literal (both handled by WGSL printer)
  (when form
    (when (eq form t) (return-from cl-webgpu/shader::walk t))
    (let ((binding (if (symbolp form)
                       (cl-webgpu/shader::get-variable-binding form)
                       form)))
      (typecase binding
        (cl-webgpu/shader::symbol-macro
         (cl-webgpu/shader::walk (cl-webgpu/shader::expansion binding) walker))
        (cl-webgpu/shader::binding
         (make-instance 'cl-webgpu/shader::variable-read
                        :binding binding))
        (number
         form)
        (vector
         form)
        ((or cl-webgpu/shader::variable-read cl-webgpu/shader::variable-write
             cl-webgpu/shader::binding-scope
             cl-webgpu/shader::slot-access cl-webgpu/shader::swizzle-access
             cl-webgpu/shader::array-access
             cl-webgpu/shader::function-call cl-webgpu/shader::global-function
             cl-webgpu/shader::explicit-progn cl-webgpu/shader::for-loop
             cl-webgpu/shader::interface-type cl-webgpu/shader::concrete-type
             cl-webgpu/shader::array-initialization
             cl-webgpu/shader::interface-stage-binding
             cl-webgpu/shader::struct-type
             cl-webgpu/shader::struct-construction)
         form)
        (t (break "unknown binding ~s / ~s (~s)" form binding cl-webgpu/shader::*environment*))))))



#++
(let ((cl-webgpu/shader::*environment*
        (make-instance 'cl-webgpu/shader::environment
                       :parent *shader-base-environment*)))
  (cl-webgpu/shader::walk '(progn
                        (defmacro do-stuff (a)
                          `(doing-stuff ,a))
                        (cond
                          ((= foo 1)
                           (do-stuff foo)
                           (more foo = 1))
                          ((= bar 2))
                          (t (default stuff))))
                      (make-instance 'cl-webgpu/shader::cl-walker)))



;;; start defining some shader functions
(%shader-macro expt (a b)
  `(pow ,a ,b))



(cl:defun call-with-package-environment (thunk &key (package *package*))
  (let ((cl-webgpu/shader::*environment* (ensure-package-environment package))
        (cl-webgpu/shader::*global-environment* (ensure-package-environment package)))
    (funcall thunk)))

(cl:defmacro with-package-environment ((&optional symbol) &body body)
  `(call-with-package-environment (lambda () ,@body)
                                  :package ,(if symbol
                                                `(symbol-package ,symbol)
                                                '*package*)))

;;; api for defining shader code from CL code
;; (as opposed to compiling a block of shader code as shader code, which can
;;  just use DEFUN etc directly)

(cl:defmacro shader-defun (name args &body body)
  `(with-package-environment ()
     (cl-webgpu/shader::walk '(cl:defun ,name ,args ,@body)
                         (make-instance 'cl-webgpu/shader::extract-functions))))

(cl:defmacro shader-defconstant (name value type)
  `(with-package-environment ()
     (cl-webgpu/shader::walk '(%defconstant ,name ,value ,type)
                         (make-instance 'cl-webgpu/shader::extract-functions))))

(cl:defmacro shader-interface (name (&rest args &key in out uniform) &body slots)
  (declare (ignore in out uniform))
  `(with-package-environment ()
     (cl-webgpu/shader::walk '(interface ,name ,args ,@slots)
                         (make-instance 'cl-webgpu/shader::extract-functions))))

(cl:defmacro shader-attribute (name type &rest args &key location)
  (declare (ignore location))
  `(with-package-environment ()
     (cl-webgpu/shader::walk '(attribute ,name ,type ,@args)
                         (make-instance 'cl-webgpu/shader::extract-functions))))

(cl:defmacro shader-input (name type &rest args &key stage location)
  (declare (ignore location stage))
  `(with-package-environment ()
     (cl-webgpu/shader::walk '(input ,name ,type ,@args)
                         (make-instance 'cl-webgpu/shader::extract-functions))))

(cl:defmacro shader-output (name type &rest args &key stage location)
  (declare (ignore location stage))
  `(with-package-environment ()
     (cl-webgpu/shader::walk '(output ,name ,type ,@args)
                         (make-instance 'cl-webgpu/shader::extract-functions))))

(cl:defmacro shader-uniform (name type &rest args &key  stage location group binding)
  (declare (ignore location stage group binding))
  `(with-package-environment ()
     (cl-webgpu/shader::walk '(uniform ,name ,type ,@args)
                         (make-instance 'cl-webgpu/shader::extract-functions))))

(cl:defmacro shader-bind-interface (stage block-name interface-qualifier instance-name)
  `(with-package-environment ()
     (cl-webgpu/shader::walk '(bind-interface ,stage ,block-name
                           ,interface-qualifier ,instance-name)
                         (make-instance 'cl-webgpu/shader::extract-functions))))
