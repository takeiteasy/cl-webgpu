(in-package #:cl-webgpu/shader)

;;; Base printer infrastructure for the WGSL backend.
;;; Provides name translation, operator printers, and type translation.

(defparameter *in-expression* nil)
(defparameter *wgsl-name-mode* nil
  "When true, %translate-name uses snake_case (lc-underscore) by default.")

;; hack to rename a specific function as 'main' when printing, so we
;; can define a bunch of shaders for different stages (or different
;; features) in same package without worrying about which can be named
;; MAIN.
(defparameter *print-as-main* nil)

;; we need to rename variables in some cases to avoid conflicts so
;; track which variables are live to avoid creating other conflicts in
;; the process
;; target name -> lisp symbol
(defparameter *live-variables* (make-hash-table :test 'equal))

;;; Name translation

(defun %translate-name (x &key lc-underscore)
  (unless (stringp x)
    (setf x (string x)))
  (with-output-to-string (s)
    (if (char= #\+ (char x 0) (char x (1- (length x))))
        (with-standard-io-syntax
          (format s "~:@(~a~)" (substitute #\_ #\- (remove #\+ x))))
        (if (or lc-underscore *wgsl-name-mode*)
            (format s "~(~a~)" (substitute #\_ #\- (remove #\+ x)))
            (loop with uc = 0
               for c across (string x)
               do (case c
                    (#\* (incf uc 1))
                    (#\- (incf uc 1))
                    (#\+
                     (incf uc 1)
                     (format s "_"))
                    (#\% (format s "_"))
                    (t (if (plusp uc)
                           (format s "~:@(~c~)" c)
                           (format s "~(~c~)" c))
                     (setf uc (max 0 (1- uc))))))))))

(defmethod translate-name (x)
  (%translate-name x))

(defmethod translate-name ((x binding))
  (when (and (boundp '*wgsl-rename-table*) *wgsl-rename-table*)
    (let ((renamed (gethash x *wgsl-rename-table*)))
      (when renamed (return-from translate-name renamed))))
  (let ((n (or (target-name x) (%translate-name (name x)))))
    (when (or (conflicts x)
              (and (gethash n *live-variables*)
                   (not (eq (name (gethash n *live-variables*)) (name x)))))
      (loop for i from 2 below 1000
            for rn = (format nil "~a_~a" n i)
            for c = (gethash rn *live-variables*)
            while (and c (not (eq c x)))
            finally (setf n rn)))
    n))

(defmethod translate-name ((x function-binding))
  (if (eq x *print-as-main*)
      "main"
      (or (target-name x) (%translate-name (name x)))))

(defmethod translate-name ((x slot-access))
  (format nil "~a.~a" (binding x)
          (translate-slot-name (field x) (binding x))))

(defmethod translate-name ((x swizzle-access))
  (format nil "~a.~a" (binding x)
          (translate-slot-name (field x) (binding x))))

(defmethod translate-name ((x array-access))
  (format nil "~a[~a]" (binding x)
          (index x)))

(defmethod translate-slot-name (x b)
  (%translate-name x))

(defmethod translate-slot-name (x (b variable-read))
  (or (translate-slot-name x (binding b))
      (%translate-name x)))

(defmethod translate-slot-name (x (b array-access))
  (or (translate-slot-name x (binding b))
      (%translate-name x)))

(defmethod translate-slot-name (x (b interface-binding))
  (or (translate-slot-name x (stage-binding b))
      (%translate-name x)))

(defmethod translate-slot-name (x (b interface-stage-binding))
  (when (or (interface-block b) (typep (binding b) 'bindings))
    (let ((b2 (bindings (or (interface-block b) (binding b)))))
      (loop for binding in b2
            when (eq (name binding) x)
              do (return-from translate-slot-name (or (target-name binding)
                                                      (%translate-name x)))))
    (%translate-name x)))

(defmethod translate-name ((x interface-stage-binding))
  (translate-name (or (interface-block x) (binding x))))

(defmethod translate-name ((x generic-type))
  (or (target-name x) (%translate-name (name (get-equiv-type x)))))

(defmethod translate-name ((x array-type))
  (translate-name (base-type x)))

(defmethod translate-name ((x variable-read))
  (translate-name (binding x)))

;;; Type translation

(defmethod translate-type (type)
  (string type))

(defmethod translate-type ((type any-type))
  "T")

(defmethod translate-type ((type ref-type))
  (translate-type (get-equiv-type type)))

(defmethod translate-type ((type concrete-type))
  (target-name type))

(defmethod translate-type ((type constrained-type))
  (let ((types))
    (maphash (lambda (k v) (when v (push k types))) (types type))
    (if (= 1 (length types))
        (translate-name (car types))
        (mapcar #'translate-name types))))

(defmethod translate-type ((type generic-type))
  (let ((e (get-equiv-type type)))
    (if (eq type e)
        (string type)
        (translate-type e))))

(defmethod translate-type ((type array-type))
  (translate-type (base-type
                   (or (and (boundp '*binding-types*)
                            (gethash type *binding-types*))
                       (value-type type)))))

(defmethod translate-type ((type struct-type))
  (or (target-name type) (%translate-name (name type))))

;;; Statement assertion macro

(defmacro assert-statement ()
  `(when *in-expression*
     (with-standard-io-syntax
       (error "trying to print statement in expression context"))))

;;; Internal function printer dispatch (used by operators)

(defparameter *internal-function-printers* (make-hash-table))

(defmacro defprinti ((form &rest args) (&optional (call (gensym))) &body body)
  (alexandria:with-gensyms (stream object)
    `(setf (gethash ',form *internal-function-printers*)
           (lambda (,stream ,object &key ((:call ,call) nil))
             (declare (ignorable ,call))
             (let ((*standard-output* ,stream))
               (destructuring-bind (,@args) ,object
                 ,@body))))))

(defmacro defprint-binop (op c-op 0-arg 1-arg)
  `(defprinti (,op &rest args) ()
     (let ((*in-expression* t))
       (case (length args)
         (0 ,(or 0-arg `(error ,(format nil "no arguments to ~a ?" op))))
         (1 ,(or
              (if (eq 1-arg t)
                  `(format t "~a" (car args))
                  1-arg)
              `(format t ,(format nil "(~a~~a)" c-op) (car args))))
         (t (format t ,(format nil "(~~{~~a~~^ ~~#[~~:;~a ~~]~~})" c-op) args))))))

;;; Binary operator printers
(defprint-binop - "-" nil nil)
(defprint-binop + "+" 0.0 t)
(defprint-binop * "*" 1.0 t)
(defprint-binop / "/" 1.0 (format t "(1.0 / ~a)" (car args)))
(defprint-binop or "||" 0 t)
(defprint-binop and "&&" 1 t)
(defprint-binop cl-webgpu/shader/internal:^^ "^^" 0 t)
(defprint-binop logior "|" 0 t)
(defprint-binop logand "&" #xffffffff t)
(defprint-binop logxor "^" 0 t)

;;; Unary / special operator printers
(defprinti (1- x) ()
  (let ((*in-expression* t))
    (format t "(~a - 1)" x)))
(defprinti (1+ x) ()
  (let ((*in-expression* t))
    (format t "(~a + 1)" x)))
(defprinti (not x) ()
  (let ((*in-expression* t))
    (format t "(!~a)" x)))

(defprinti (cl-webgpu/shader/internal::incf x &optional y) ()
  (let ((*in-expression* t))
    (if y
        (format t "(~a+=~a)" x y)
        (format t "(~a++)" x))))
(defprinti (cl-webgpu/shader/internal::decf x &optional y) ()
  (let ((*in-expression* t))
    (if y
        (format t "(~a-=~a)" x y)
        (format t "(~a--)" x))))

(defprinti (cl-webgpu/shader/internal::++ x) ()
  (let ((*in-expression* t))
    (format t "(++~a)" x)))
(defprinti (cl-webgpu/shader/internal::-- x) ()
  (let ((*in-expression* t))
    (format t "(--~a)" x)))

;;; Integral type check (used by mod, zerop, etc.)

(defmethod integral-type ((type concrete-type))
  (and (scalar/vector-set type)
       (member (name (aref (scalar/vector-set type) 1))
               '(:int :uint))))

(defmethod integral-type ((type constrained-type))
  (some #'integral-type (alexandria:hash-table-keys (types type))))

(defprinti (mod a b) (call)
  (let ((*in-expression* t)
        (type (gethash call *binding-types*)))
    (with-standard-io-syntax
      (assert type))
    (if (integral-type (first type))
        (format t "(~a % ~a)" a b)
        (format t "mod(~a, ~a)" a b))))

;;; Comparison operators
(macrolet ((compares (&rest ops)
             `(progn
                ,@(loop for (op c-op) in ops
                        collect `(defprinti (,op a b) ()
                                   (let ((*in-expression* t))
                                     (format t ,(format nil"(~~a ~a ~~a)" c-op)
                                             a b)))))))
  (compares (= "==")
            (/= "!=")
            (< "<")
            (> ">")
            (<= "<=")
            (>= ">=")))

(defprinti (zerop x) (call)
  (let ((*in-expression* t)
        (type (gethash call *binding-types*)))
    (with-standard-io-syntax
      (assert type))
    (if (integral-type (second type))
        (format t "(0 == ~a)" x)
        (format t "(0.0 == ~a)" x))))

(defprinti (plusp x) (call)
  (let ((*in-expression* t)
        (type (gethash call *binding-types*)))
    (with-standard-io-syntax
      (assert type))
    (if (integral-type (second type))
        (format t "(~a > 0)" x)
        (format t "(~a > 0.0)" x))))

(defprinti (minusp x) (call)
  (let ((*in-expression* t)
        (type (gethash call *binding-types*)))
    (with-standard-io-syntax
      (assert type))
    (if (integral-type (second type))
        (format t "(~a < 0)" x)
        (format t "(~a < 0.0)" x))))

(defprinti (ash i c) ()
  (cond
    ((numberp c)
     (let ((*in-expression* t))
       (format t "(~a ~a ~a)" i (if (plusp c) "<<" ">>") (abs c))))
    (t (error "tried to print ASH with non-constant shift?"))))

(defprinti (cl-webgpu/shader/internal::<< i c) ()
 (let ((*in-expression* t))
   (format t "(~a << ~a)" i c)))

(defprinti (cl-webgpu/shader/internal::>> i c) ()
 (let ((*in-expression* t))
   (format t "(~a >> ~a)" i c)))

(defprinti (return x) ()
  (assert-statement)
  (let ((*in-expression* t))
    (format t "return ~a" x)))

(defprinti (values &optional x) ()
  (when x
    (let ((*in-expression* t))
      (format t "~a" x))))

(defprinti (cl-webgpu/shader/internal:discard) ()
  (assert-statement)
  (format t "discard"))

;;; Array suffix helpers

(defmethod array-suffix (x)
  nil)

(defmethod array-suffix ((x array-type))
  (typecase (array-size x)
    (number (format nil "[~a]" (array-size x)))
    (null nil)
    ((or symbol binding) (format nil "[~a]" (translate-name (array-size x))))
    (t "[]")))

(defmethod array-suffix ((x interface-binding))
  (typecase (array-size x)
    (number (format nil "[~a]" (array-size x)))
    (null nil)
    (t "[]")))

(defmethod array-suffix ((x interface-stage-binding))
  (typecase (array-size x)
    (number (format nil "[~a]" (array-size x)))
    (null nil)
    (t "[]")))
