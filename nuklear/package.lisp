(defpackage #:cl-webgpu/nuklear
  (:use #:cl)
  (:export
   ;; Backend API
   #:make-nuklear-renderer
   #:render-nuklear
   #:free-nuklear-renderer
   #:nuklear-renderer-atlas-pixels
   #:nuklear-renderer-atlas-width
   #:nuklear-renderer-atlas-height
   #:nuklear-renderer-atlas-null-tex))

;;; Forward all home symbols from the nuklear package, stripping the "NK-" prefix.
;;; This runs after cl-nuklear has been loaded (it's a dependency of this system).
;;; CFFI struct types keep their nk- prefix in slot-access forms (e.g. (:struct nuklear::nk-rect))
;;; since CFFI type keys are symbols — function definitions are forwarded under the stripped name.
(eval-when (:compile-toplevel :load-toplevel :execute)
  (let ((nk (find-package :nuklear)))
    (do-symbols (s nk)
      (when (eq (symbol-package s) nk)
        (let* ((name     (symbol-name s))
               (stripped (if (and (>= (length name) 3)
                                  (string= "NK-" name :end2 3))
                             (subseq name 3)
                             name)))
          ;; Shadow before interning so CL package symbols (e.g. NULL from NK-NULL)
          ;; don't leak through (:use #:cl) and cause locked-package errors.
          (shadow stripped :cl-webgpu/nuklear)
          (let ((new-sym (intern stripped :cl-webgpu/nuklear)))
            ;; Forward plain function definitions (not macros — fdefinition rejects them)
            (when (and (fboundp s) (not (macro-function s)))
              (unless (fboundp new-sym)
                (setf (fdefinition new-sym) (fdefinition s))))
            ;; Forward macro definitions
            (when (macro-function s)
              (unless (macro-function new-sym)
                (setf (macro-function new-sym) (macro-function s))))
            ;; Forward constants / special variables
            (when (and (boundp s) (not (eq s new-sym)))
              (unless (boundp new-sym)
                (setf (symbol-value new-sym) (symbol-value s))))
            (export new-sym :cl-webgpu/nuklear)))))))
