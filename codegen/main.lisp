;;;; codegen/main.lisp
;;;; Entry point for the cl-webgpu codegen.

(in-package #:cl-webgpu-codegen)

(defun resolve-path (base p)
  (if (uiop:absolute-pathname-p p)
      p
      (uiop:subpathname base p)))

(defun generate (&key (webgpu-h    "deps/webgpu/webgpu.h")
                      (wgpu-h      "deps/webgpu/wgpu.h")
                      (out-package      "src/package.lisp")
                      (out-types        "src/types.lisp")
                      (out-functions    "src/functions.lisp")
                      (out-shim         "src/functions-shim.lisp"))
  "Generate cl-webgpu CFFI bindings from C headers.

Reads WEBGPU-H and WGPU-H, then writes:
  OUT-PACKAGE   — src/package.lisp       (defpackage with all exports)
  OUT-TYPES     — src/types.lisp         (defctype/defcenum/defcstruct/defconstant)
  OUT-FUNCTIONS — src/functions.lisp     (defcfun + shim defun wrappers)
  OUT-SHIM      — src/functions-shim.lisp (defcfun for shim C functions)

Paths are relative to the current working directory, or pass absolute paths.

Typical usage from the cl-webgpu project root:
  (cl-webgpu-codegen:generate)"
  (let* ((base (uiop:getcwd)))
    (flet ((p (x) (namestring (resolve-path base x))))
      (format t "~&Parsing ~A ...~%" (p webgpu-h))
      (format t "~&Parsing ~A ...~%" (p wgpu-h))
      (let ((ctx (parse-headers (p webgpu-h) (p wgpu-h))))
        (format t "~&Parsed ~A declarations.~%"
                (length (parse-context-declarations ctx)))
        (dolist (spec (list (list out-package      #'generate-package-file)
                            (list out-types        #'generate-types-file)
                            (list out-functions    #'generate-functions-file)
                            (list out-shim         #'generate-functions-shim-file)))
          (let ((path (p (first spec)))
                (fn   (second spec)))
            (format t "~&Writing ~A ...~%" path)
            (with-open-file (out path
                                 :direction :output
                                 :if-exists :supersede
                                 :if-does-not-exist :create)
              (funcall fn ctx out))))
        (format t "~&Done.~%")
        (values)))))
