;;;; codegen/lisp-generator.lisp
;;;; Converts parsed C declarations to CFFI Lisp forms.

(in-package #:cl-webgpu-codegen)

;;; Primitive C → CFFI type mapping

(defparameter *shimmed-functions*
  '(;; Entry format: (original-name shim-name return-type (param-sym cffi-type) ...)
    ;; C name is derived from shim-name by substituting _ for -.
    ("wgpu-get-proc-address" "wgpu-shim-get-proc-address" :pointer
     (proc-name-data :pointer) (proc-name-length :size))

    ;; FreeMembers
    ("wgpu-adapter-info-free-members" "wgpu-shim-adapter-info-free-members" :void
     (info :pointer))
    ("wgpu-supported-features-free-members" "wgpu-shim-supported-features-free-members" :void
     (features :pointer))
    ("wgpu-supported-instance-features-free-members" "wgpu-shim-supported-instance-features-free-members" :void
     (features :pointer))
    ("wgpu-supported-wgsl-language-features-free-members" "wgpu-shim-supported-wgsl-language-features-free-members" :void
     (features :pointer))
    ("wgpu-surface-capabilities-free-members" "wgpu-shim-surface-capabilities-free-members" :void
     (capabilities :pointer))

    ;; SetLabel / debug marker
    ("wgpu-bind-group-set-label" "wgpu-shim-bind-group-set-label" :void
     (bind-group wgpu-bind-group) (data :pointer) (length :size))
    ("wgpu-bind-group-layout-set-label" "wgpu-shim-bind-group-layout-set-label" :void
     (bind-group-layout wgpu-bind-group-layout) (data :pointer) (length :size))
    ("wgpu-buffer-set-label" "wgpu-shim-buffer-set-label" :void
     (buffer wgpu-buffer) (data :pointer) (length :size))
    ("wgpu-command-buffer-set-label" "wgpu-shim-command-buffer-set-label" :void
     (command-buffer wgpu-command-buffer) (data :pointer) (length :size))
    ("wgpu-command-encoder-insert-debug-marker" "wgpu-shim-command-encoder-insert-debug-marker" :void
     (command-encoder wgpu-command-encoder) (data :pointer) (length :size))
    ("wgpu-command-encoder-push-debug-group" "wgpu-shim-command-encoder-push-debug-group" :void
     (command-encoder wgpu-command-encoder) (data :pointer) (length :size))
    ("wgpu-command-encoder-set-label" "wgpu-shim-command-encoder-set-label" :void
     (command-encoder wgpu-command-encoder) (data :pointer) (length :size))
    ("wgpu-compute-pass-encoder-insert-debug-marker" "wgpu-shim-compute-pass-encoder-insert-debug-marker" :void
     (compute-pass-encoder wgpu-compute-pass-encoder) (data :pointer) (length :size))
    ("wgpu-compute-pass-encoder-push-debug-group" "wgpu-shim-compute-pass-encoder-push-debug-group" :void
     (compute-pass-encoder wgpu-compute-pass-encoder) (data :pointer) (length :size))
    ("wgpu-compute-pass-encoder-set-label" "wgpu-shim-compute-pass-encoder-set-label" :void
     (compute-pass-encoder wgpu-compute-pass-encoder) (data :pointer) (length :size))
    ("wgpu-compute-pipeline-set-label" "wgpu-shim-compute-pipeline-set-label" :void
     (compute-pipeline wgpu-compute-pipeline) (data :pointer) (length :size))
    ("wgpu-device-set-label" "wgpu-shim-device-set-label" :void
     (device wgpu-device) (data :pointer) (length :size))
    ("wgpu-external-texture-set-label" "wgpu-shim-external-texture-set-label" :void
     (external-texture wgpu-external-texture) (data :pointer) (length :size))
    ("wgpu-pipeline-layout-set-label" "wgpu-shim-pipeline-layout-set-label" :void
     (pipeline-layout wgpu-pipeline-layout) (data :pointer) (length :size))
    ("wgpu-query-set-set-label" "wgpu-shim-query-set-set-label" :void
     (query-set wgpu-query-set) (data :pointer) (length :size))
    ("wgpu-queue-set-label" "wgpu-shim-queue-set-label" :void
     (queue wgpu-queue) (data :pointer) (length :size))
    ("wgpu-render-bundle-set-label" "wgpu-shim-render-bundle-set-label" :void
     (render-bundle wgpu-render-bundle) (data :pointer) (length :size))
    ("wgpu-render-bundle-encoder-insert-debug-marker" "wgpu-shim-render-bundle-encoder-insert-debug-marker" :void
     (render-bundle-encoder wgpu-render-bundle-encoder) (data :pointer) (length :size))
    ("wgpu-render-bundle-encoder-push-debug-group" "wgpu-shim-render-bundle-encoder-push-debug-group" :void
     (render-bundle-encoder wgpu-render-bundle-encoder) (data :pointer) (length :size))
    ("wgpu-render-bundle-encoder-set-label" "wgpu-shim-render-bundle-encoder-set-label" :void
     (render-bundle-encoder wgpu-render-bundle-encoder) (data :pointer) (length :size))
    ("wgpu-render-pass-encoder-insert-debug-marker" "wgpu-shim-render-pass-encoder-insert-debug-marker" :void
     (render-pass-encoder wgpu-render-pass-encoder) (data :pointer) (length :size))
    ("wgpu-render-pass-encoder-push-debug-group" "wgpu-shim-render-pass-encoder-push-debug-group" :void
     (render-pass-encoder wgpu-render-pass-encoder) (data :pointer) (length :size))
    ("wgpu-render-pass-encoder-set-label" "wgpu-shim-render-pass-encoder-set-label" :void
     (render-pass-encoder wgpu-render-pass-encoder) (data :pointer) (length :size))
    ("wgpu-render-pipeline-set-label" "wgpu-shim-render-pipeline-set-label" :void
     (render-pipeline wgpu-render-pipeline) (data :pointer) (length :size))
    ("wgpu-sampler-set-label" "wgpu-shim-sampler-set-label" :void
     (sampler wgpu-sampler) (data :pointer) (length :size))
    ("wgpu-shader-module-set-label" "wgpu-shim-shader-module-set-label" :void
     (shader-module wgpu-shader-module) (data :pointer) (length :size))
    ("wgpu-surface-set-label" "wgpu-shim-surface-set-label" :void
     (surface wgpu-surface) (data :pointer) (length :size))
    ("wgpu-texture-set-label" "wgpu-shim-texture-set-label" :void
     (texture wgpu-texture) (data :pointer) (length :size))
    ("wgpu-texture-view-set-label" "wgpu-shim-texture-view-set-label" :void
     (texture-view wgpu-texture-view) (data :pointer) (length :size))

    ;; Async with decomposed callbacks
    ("wgpu-buffer-map-async" "wgpu-shim-buffer-map-async" :void
     (buffer wgpu-buffer) (mode wgpu-flags) (offset :size) (size :size)
     (next-in-chain :pointer) (callback-mode wgpu-callback-mode)
     (callback :pointer) (userdata1 :pointer) (userdata2 :pointer) (out-future :pointer))
    ("wgpu-adapter-request-device" "wgpu-shim-adapter-request-device" :void
     (adapter wgpu-adapter) (descriptor :pointer) (next-in-chain :pointer)
     (callback-mode wgpu-callback-mode) (callback :pointer)
     (userdata1 :pointer) (userdata2 :pointer) (out-future :pointer))
    ("wgpu-device-pop-error-scope" "wgpu-shim-device-pop-error-scope" :void
     (device wgpu-device) (next-in-chain :pointer)
     (callback-mode wgpu-callback-mode) (callback :pointer)
     (userdata1 :pointer) (userdata2 :pointer) (out-future :pointer))
    ("wgpu-queue-on-submitted-work-done" "wgpu-shim-queue-on-submitted-work-done" :void
     (queue wgpu-queue) (next-in-chain :pointer)
     (callback-mode wgpu-callback-mode) (callback :pointer)
     (userdata1 :pointer) (userdata2 :pointer) (out-future :pointer))
    ("wgpu-shader-module-get-compilation-info" "wgpu-shim-shader-module-get-compilation-info" :void
     (shader-module wgpu-shader-module) (next-in-chain :pointer)
     (callback-mode wgpu-callback-mode) (callback :pointer)
     (userdata1 :pointer) (userdata2 :pointer) (out-future :pointer))
    ("wgpu-instance-request-adapter" "wgpu-shim-instance-request-adapter" :void
     (instance wgpu-instance) (options :pointer) (next-in-chain :pointer)
     (callback-mode wgpu-callback-mode) (callback :pointer)
     (userdata1 :pointer) (userdata2 :pointer) (out-future :pointer))
    ("wgpu-device-create-compute-pipeline-async" "wgpu-shim-device-create-compute-pipeline-async" :void
     (device wgpu-device) (descriptor :pointer) (next-in-chain :pointer)
     (callback-mode wgpu-callback-mode) (callback :pointer)
     (userdata1 :pointer) (userdata2 :pointer) (out-future :pointer))
    ("wgpu-device-create-render-pipeline-async" "wgpu-shim-device-create-render-pipeline-async" :void
     (device wgpu-device) (descriptor :pointer) (next-in-chain :pointer)
     (callback-mode wgpu-callback-mode) (callback :pointer)
     (userdata1 :pointer) (userdata2 :pointer) (out-future :pointer)))
  "Maps original function names to shim dispatch info.
Each entry: (original-name shim-name return-type (param-sym cffi-type) ...).
C name of shim is derived from shim-name by substituting _ for -.
wgpu-device-get-lost-future is intentionally absent (no shim exists).")

(defparameter *shim-only-functions*
  '(;; Entry format: (c-name lisp-name return-type (param-sym cffi-type) ...)
    ;; These have no corresponding original wgpu function.
    ("wgpu_shim_set_log_callback" "wgpu-shim-set-log-callback" :void
     (callback :pointer) (userdata :pointer))
    ("wgpu_shim_instance_request_adapter_sync" "wgpu-shim-instance-request-adapter-sync"
     wgpu-request-adapter-status
     (instance wgpu-instance) (options :pointer) (out-adapter (:pointer wgpu-adapter)))
    ("wgpu_shim_adapter_request_device_sync" "wgpu-shim-adapter-request-device-sync"
     wgpu-request-device-status
     (instance wgpu-instance) (adapter wgpu-adapter) (descriptor :pointer)
     (out-device (:pointer wgpu-device)))
    ("wgpu_shim_get_silent_uncaptured_error_callback" "%get-silent-uncaptured-error-callback"
     :pointer))
  "Shim-only functions with no corresponding original wgpu function.
Each entry: (c-name lisp-name return-type (param-sym cffi-type) ...).")

(defun find-shim-entry (lisp-name)
  (find lisp-name *shimmed-functions* :key #'car :test #'string=))

(defparameter *primitive-type-map*
  '(("void"              . ":void")
    ("uint8_t"           . ":uint8")
    ("uint16_t"          . ":uint16")
    ("uint32_t"          . ":uint32")
    ("uint64_t"          . ":uint64")
    ("int8_t"            . ":int8")
    ("int16_t"           . ":int16")
    ("int32_t"           . ":int32")
    ("int64_t"           . ":int64")
    ("size_t"            . ":size")
    ("float"             . ":float")
    ("double"            . ":double")
    ("bool"              . ":bool")
    ("WGPUBool"          . "wgpu-bool")
    ("WGPUFlags"         . "wgpu-flags")
    ("WGPUProc"          . "wgpu-proc")
    ;; wgpu-native specific
    ("WGPUSubmissionIndex" . ":uint64")))

(defun resolve-cffi-type (c-type ctx)
  "Resolve a C type string to its CFFI type form string.
  CTX is the parse-context with known type registries."
  (let* ((raw (string-trim '(#\space #\tab) c-type))
         (is-ptr (pointer-type-p raw))
         (base (string-trim '(#\space #\tab) (base-type raw))))
    (cond
      (is-ptr ":pointer")
      ((assoc base *primitive-type-map* :test #'string=)
       (cdr (assoc base *primitive-type-map* :test #'string=)))
      ((gethash base (parse-context-opaque-handles ctx))
       (c-type-name-to-symbol base))
      ((gethash base (parse-context-enum-types ctx))
       (c-type-name-to-symbol base))
      ((gethash base (parse-context-flag-types ctx))
       "wgpu-flags")
      ((gethash base (parse-context-struct-types ctx))
       (format nil "(:struct ~A)" (c-type-name-to-symbol base)))
      (t ":pointer"))))

(defun struct-by-value-p (c-type ctx)
  "Return true if C-TYPE is a struct passed by value (problematic for CFFI)."
  (let* ((raw (string-trim '(#\space #\tab) c-type))
         (is-ptr (pointer-type-p raw))
         (base (string-trim '(#\space #\tab) (base-type raw))))
    (and (not is-ptr)
         (gethash base (parse-context-struct-types ctx))
         ;; WGPUBool / WGPUFlags are typedefs to primitives, not real structs
         (not (assoc base *primitive-type-map* :test #'string=)))))

(defun function-problematic-p (decl ctx)
  "Return a reason string if this function can't be directly bound, else nil."
  (let ((ret (getf decl :return-type))
        (params (getf decl :params)))
    (cond
      ((struct-by-value-p ret ctx)
       (format nil "returns ~A by value" ret))
      ((some (lambda (p) (struct-by-value-p (getf p :ctype) ctx)) params)
       (let ((bad (find-if (lambda (p) (struct-by-value-p (getf p :ctype) ctx)) params)))
         (format nil "param ~A is ~A by value" (getf bad :name) (getf bad :ctype))))
      (t nil))))

;;; ECL FFI type mapping

(defparameter *ecl-primitive-type-map*
  '(("void"     . ":void")
    ("uint8_t"  . ":uint8-t")
    ("uint16_t" . ":uint16-t")
    ("uint32_t" . ":uint32-t")
    ("uint64_t" . ":uint64-t")
    ("int8_t"   . ":int8-t")
    ("int16_t"  . ":int16-t")
    ("int32_t"  . ":int32-t")
    ("int64_t"  . ":int64-t")
    ("size_t"   . ":cl-index")
    ("float"    . ":float")
    ("double"   . ":double")
    ("bool"     . ":int")
    ("WGPUBool"           . ":uint32-t")
    ("WGPUFlags"          . ":uint64-t")
    ("WGPUProc"           . ":pointer-void")
    ("WGPUSubmissionIndex" . ":uint64-t")))

(defun resolve-ecl-type (c-type ctx)
  "Resolve a C type string to its ECL FFI type form string."
  (let* ((raw (string-trim '(#\space #\tab) c-type))
         (is-ptr (pointer-type-p raw))
         (base (string-trim '(#\space #\tab) (base-type raw))))
    (cond
      (is-ptr ":pointer-void")
      ((assoc base *ecl-primitive-type-map* :test #'string=)
       (cdr (assoc base *ecl-primitive-type-map* :test #'string=)))
      ((gethash base (parse-context-opaque-handles ctx))
       ":pointer-void")
      ((gethash base (parse-context-enum-types ctx))
       ":int")
      ((gethash base (parse-context-flag-types ctx))
       ":int")
      ((gethash base (parse-context-struct-types ctx))
       (format nil ":~A" (c-type-name-to-symbol base)))
      (t ":pointer-void"))))

;;; ECL type conversion for shim CFFI type forms

(defparameter *cffi-keyword-to-ecl*
  '((:void . ":void")
    (:pointer . ":pointer-void")
    (:size . ":cl-index")
    (:uint8 . ":uint8-t") (:uint16 . ":uint16-t")
    (:uint32 . ":uint32-t") (:uint64 . ":uint64-t")
    (:int8 . ":int8-t") (:int16 . ":int16-t")
    (:int32 . ":int32-t") (:int64 . ":int64-t")
    (:float . ":float") (:double . ":double") (:bool . ":int")))

(defun make-shim-ecl-type-map (ctx)
  "Build a hash table mapping lisp symbol name strings to ECL type strings."
  (let ((m (make-hash-table :test #'equal)))
    (maphash (lambda (k v) (declare (ignore v))
               (setf (gethash (c-type-name-to-symbol k) m) ":pointer-void"))
             (parse-context-opaque-handles ctx))
    (maphash (lambda (k v) (declare (ignore v))
               (setf (gethash (c-type-name-to-symbol k) m) ":int"))
             (parse-context-enum-types ctx))
    (maphash (lambda (k v) (declare (ignore v))
               (setf (gethash (c-type-name-to-symbol k) m) ":uint64-t"))
             (parse-context-flag-types ctx))
    (setf (gethash "wgpu-flags" m) ":uint64-t"
          (gethash "wgpu-bool" m) ":uint32-t"
          (gethash "wgpu-proc" m) ":pointer-void")
    m))

(defun shim-type-to-ecl (type ecl-map)
  "Convert a CFFI type form (keyword, symbol, or (:pointer X) list) to an ECL type string."
  (cond
    ((and (listp type) (eq (car type) :pointer)) ":pointer-void")
    ((keywordp type)
     (or (cdr (assoc type *cffi-keyword-to-ecl*)) ":pointer-void"))
    (t
     (or (gethash (string-downcase (symbol-name type)) ecl-map)
         ":pointer-void"))))

;;; Output helpers

(defun write-section-header (out title)
  (format out "~%;; ~69,,,'-<~>~%;; ~A~%;; ~69,,,'-<~>~%~%" title))

(defun write-preamble (out filename)
  (format out ";;;; ~A~%" filename)
  (format out ";;;; AUTO-GENERATED by cl-webgpu-codegen. Do not edit manually.~%")
  (format out ";;;; Run (cl-webgpu-codegen:generate) to regenerate.~%~%")
  (format out "(in-package #:cl-webgpu)~%"))

;;; Generators for each declaration kind

(defun gen-opaque (decl out)
  (let ((sym (c-type-name-to-symbol (getf decl :name))))
    (format out "#-(ecl)~%(defctype ~A :pointer)~%" sym)
    (format out "#+(ecl)~%(ffi:def-foreign-type ~A :pointer-void)~%~%" sym)))

(defun gen-enum (decl out)
  (let ((name (c-type-name-to-symbol (getf decl :name)))
        (values (getf decl :values)))
    (if (null values)
        (progn
          (format out "#-(ecl)~%;; (defcenum ~A) ; no values~%" name)
          (format out "#+(ecl)~%;; ~A has no values~%~%" name))
        (progn
          (format out "#-(ecl)~%")
          (format out "(defcenum ~A~%" name)
          (loop for (c-val-name . val) in values
                for i from 0
                for kw = (c-enum-value-to-keyword-string (getf decl :name) c-val-name)
                do (if (= i (1- (length values)))
                       (format out "  (:~A #x~X))~%" kw val)
                       (format out "  (:~A #x~X)~%" kw val)))
          (format out "#+(ecl)~%(ffi:def-foreign-type ~A :int)~%~%" name)))))

(defun gen-flag-group (declarations flag-type-name out)
  "Emit all flag constants for a given flag type."
  (let ((type-sym (c-type-name-to-symbol flag-type-name)))
    (format out "~%;; ~A flags~%" type-sym)
    (dolist (decl declarations)
      (when (and (eq (getf decl :kind) :flag-value)
                 (string= (getf decl :flag-type) flag-type-name))
        (let* ((constant-str (c-flag-name-to-constant-string (getf decl :name)))
               (val (getf decl :value)))
          (format out "(defconstant ~A~A)~%"
                  constant-str
                  (if (= val 0)
                      " 0"
                      (format nil " #x~X" val))))))))

(defun gen-struct (decl ctx out)
  (let ((name (c-type-name-to-symbol (getf decl :name)))
        (fields (getf decl :fields)))
    ;; CFFI form
    (format out "#-(ecl)~%")
    (if (null fields)
        (format out "(defcstruct ~A)~%" name)
        (progn
          (format out "(defcstruct ~A~%" name)
          (loop for field in fields
                for i from 0
                for field-sym = (c-field-name-to-symbol (getf field :name))
                for cffi-type = (resolve-cffi-type (getf field :ctype) ctx)
                do (if (= i (1- (length fields)))
                       (format out "  (~A ~A))~%" field-sym cffi-type)
                       (format out "  (~A ~A)~%" field-sym cffi-type)))))
    ;; ECL form
    (format out "#+(ecl)~%")
    (if (null fields)
        (format out "(ffi:def-struct ~A)~%~%" name)
        (progn
          (format out "(ffi:def-struct ~A~%" name)
          (loop for field in fields
                for i from 0
                for field-sym = (c-field-name-to-symbol (getf field :name))
                for ecl-type = (resolve-ecl-type (getf field :ctype) ctx)
                do (if (= i (1- (length fields)))
                       (format out "  (~A ~A))~%~%" field-sym ecl-type)
                       (format out "  (~A ~A)~%" field-sym ecl-type)))))))

(defun gen-shim-wrapper (lisp-name shim-entry out)
  (let* ((shim-name (cadr shim-entry))
         (params (cdddr shim-entry))
         (param-syms (mapcar (lambda (p) (string-downcase (symbol-name (car p)))) params)))
    (format out "~%(defun ~A (~{~A~^ ~})~%" lisp-name param-syms)
    (format out "  (~A~{ ~A~}))~%" shim-name param-syms)))

(defun gen-function (decl ctx out)
  (let* ((c-name (getf decl :name))
         (lisp-name (c-name-to-lisp-symbol c-name))
         (ret-cffi (resolve-cffi-type (getf decl :return-type) ctx))
         (params (getf decl :params))
         (reason (function-problematic-p decl ctx)))
    (if reason
        (let ((shim-entry (find-shim-entry lisp-name)))
          (if shim-entry
              (gen-shim-wrapper lisp-name shim-entry out)
              (format out "~%;; NOTE: ~A skipped (~A) - no shim available~%" lisp-name reason)))
        ;; CFFI form
        (progn
          (format out "~%#-(ecl)~%")
          (if (null params)
              (format out "(defcfun (~S ~A) ~A)~%" c-name lisp-name ret-cffi)
              (progn
                (format out "(defcfun (~S ~A) ~A~%" c-name lisp-name ret-cffi)
                (loop for p in params
                      for i from 0
                      for p-sym = (c-field-name-to-symbol (getf p :name))
                      for p-type = (resolve-cffi-type (getf p :ctype) ctx)
                      do (if (= i (1- (length params)))
                             (format out "  (~A ~A))~%" p-sym p-type)
                             (format out "  (~A ~A)~%" p-sym p-type)))))
          ;; ECL form
          (let ((ret-ecl (resolve-ecl-type (getf decl :return-type) ctx)))
            (format out "#+(ecl)~%")
            (if (null params)
                (format out "(ffi:def-function (~S ~A) ()~%  :result-type ~A :language :c)~%"
                        c-name lisp-name ret-ecl)
                (progn
                  (format out "(ffi:def-function (~S ~A)~%" c-name lisp-name)
                  (format out "    (")
                  (loop for p in params
                        for i from 0
                        for p-sym = (c-field-name-to-symbol (getf p :name))
                        for p-ecl  = (resolve-ecl-type (getf p :ctype) ctx)
                        do (if (= i 0)
                               (format out "(~A ~A)" p-sym p-ecl)
                               (format out "~%     (~A ~A)" p-sym p-ecl)))
                  (format out ")~%  :result-type ~A :language :c)~%" ret-ecl))))))))

;;; Main generation functions

(defun generate-types-file (ctx out)
  "Write src/types.lisp content to OUT stream."
  (write-preamble out "types.lisp")
  (let ((decls (parse-context-declarations ctx)))

    (write-section-header out "Opaque handle types")
    (dolist (d decls)
      (when (eq (getf d :kind) :opaque)
        (gen-opaque d out)))

    ;; Emit WGPUFlags, WGPUBool, WGPUProc type aliases
    (terpri out)
    (format out ";; Type aliases~%")
    (format out "#-(ecl)~%(defctype wgpu-flags :uint64)~%")
    (format out "#+(ecl)~%(ffi:def-foreign-type wgpu-flags :uint64-t)~%~%")
    (format out "#-(ecl)~%(defctype wgpu-bool :uint32)~%")
    (format out "#+(ecl)~%(ffi:def-foreign-type wgpu-bool :uint32-t)~%~%")
    (format out "#-(ecl)~%(defctype wgpu-proc :pointer)~%")
    (format out "#+(ecl)~%(ffi:def-foreign-type wgpu-proc :pointer-void)~%~%")

    (write-section-header out "Enumerations")
    (dolist (d decls)
      (when (eq (getf d :kind) :enum)
        (gen-enum d out)
        (terpri out)))

    (write-section-header out "Bitflag constants")
    ;; Collect all flag types in order, emit each group
    (let ((seen-flag-types '()))
      (dolist (d decls)
        (when (eq (getf d :kind) :flag-type)
          (unless (member (getf d :name) seen-flag-types :test #'string=)
            (push (getf d :name) seen-flag-types)
            (gen-flag-group decls (getf d :name) out)))))

    (write-section-header out "Structures")
    (dolist (d decls)
      (when (eq (getf d :kind) :struct)
        (gen-struct d ctx out)
        (terpri out)))))

(defun generate-functions-file (ctx out)
  "Write src/functions.lisp content to OUT stream."
  (write-preamble out "functions.lisp")
  (let ((decls (parse-context-declarations ctx)))
    (dolist (d decls)
      (when (eq (getf d :kind) :function)
        (gen-function d ctx out)))))

(defun fmt-cffi-type (type)
  "Format a CFFI type (keyword, symbol, or (:pointer X) list) as a lowercase string.
  ~A drops the : prefix for keywords (princ with *print-escape* nil), so we handle
  keywords and lists explicitly."
  (cond
    ((keywordp type)
     (format nil ":~A" (string-downcase (symbol-name type))))
    ((listp type)
     (format nil "(~{~A~^ ~})" (mapcar #'fmt-cffi-type type)))
    ((symbolp type)
     (string-downcase (symbol-name type)))
    (t (string-downcase (format nil "~A" type)))))

(defun gen-shim-defcfun (c-name lisp-name return-type params ecl-map out)
  "Emit a single shim defcfun with its ECL ffi:def-function counterpart."
  (let ((ret-str  (fmt-cffi-type return-type))
        (ret-ecl  (shim-type-to-ecl return-type ecl-map)))
    (format out "~%#-(ecl)~%")
    (if (null params)
        (format out "(defcfun (~S ~A) ~A)~%" c-name lisp-name ret-str)
        (progn
          (format out "(defcfun (~S ~A) ~A~%" c-name lisp-name ret-str)
          (loop for p in params
                for i from 0
                for p-sym  = (string-downcase (symbol-name (car p)))
                for p-type = (fmt-cffi-type (cadr p))
                do (if (= i (1- (length params)))
                       (format out "  (~A ~A))~%" p-sym p-type)
                       (format out "  (~A ~A)~%" p-sym p-type)))))
    (format out "#+(ecl)~%")
    (if (null params)
        (format out "(ffi:def-function (~S ~A) ()~%  :result-type ~A :language :c)~%"
                c-name lisp-name ret-ecl)
        (progn
          (format out "(ffi:def-function (~S ~A)~%" c-name lisp-name)
          (format out "    (")
          (loop for p in params
                for i from 0
                for p-sym = (string-downcase (symbol-name (car p)))
                for p-ecl = (shim-type-to-ecl (cadr p) ecl-map)
                do (if (= i 0)
                       (format out "(~A ~A)" p-sym p-ecl)
                       (format out "~%     (~A ~A)" p-sym p-ecl)))
          (format out ")~%  :result-type ~A :language :c)~%" ret-ecl)))))

(defun generate-functions-shim-file (ctx out)
  "Write src/functions-shim.lisp content to OUT stream."
  (write-preamble out "functions-shim.lisp")
  (let ((ecl-map (make-shim-ecl-type-map ctx)))
    (write-section-header out "Shim bindings replacing struct-by-value APIs")
    (dolist (entry *shimmed-functions*)
      (let* ((shim-name   (cadr entry))
             (return-type (caddr entry))
             (params      (cdddr entry))
             (c-name      (substitute #\_ #\- shim-name)))
        (gen-shim-defcfun c-name shim-name return-type params ecl-map out)))
    (write-section-header out "Shim-only helper functions")
    (dolist (entry *shim-only-functions*)
      (let* ((c-name      (car entry))
             (lisp-name   (cadr entry))
             (return-type (caddr entry))
             (params      (cdddr entry)))
        (gen-shim-defcfun c-name lisp-name return-type params ecl-map out)))))

;;; Package file generation

(defparameter *static-extra-exports*
  '("load-wgpu-libraries"
    "wgpu-shim-make-string-view")
  "Symbols from hand-maintained files that should always be exported.")

(defun collect-export-symbols (ctx)
  "Return a sorted list of symbol name strings to export from cl-webgpu."
  (let ((syms '())
        (decls (parse-context-declarations ctx)))
    ;; Opaque handles, enum types, struct types, flag types → their type symbol names
    (dolist (d decls)
      (case (getf d :kind)
        ((:opaque :enum :struct :flag-type)
         (push (c-type-name-to-symbol (getf d :name)) syms))
        (:flag-value
         (push (c-flag-name-to-constant-string (getf d :name)) syms))
        (:function
         (let ((lisp-name (c-name-to-lisp-symbol (getf d :name))))
           (when (or (not (function-problematic-p d ctx))
                     (find-shim-entry lisp-name))
             (push lisp-name syms))))))
    ;; Type aliases always present
    (dolist (alias '("wgpu-flags" "wgpu-bool" "wgpu-proc"))
      (push alias syms))
    ;; Shim function names from *shimmed-functions* and *shim-only-functions*
    (dolist (entry *shimmed-functions*)
      (push (cadr entry) syms))
    (dolist (entry *shim-only-functions*)
      (push (cadr entry) syms))
    ;; Hand-maintained extras
    (dolist (extra *static-extra-exports*)
      (push extra syms))
    (sort (remove-duplicates syms :test #'string=) #'string<)))

(defun generate-package-file (ctx out)
  "Write src/package.lisp content to OUT stream."
  (format out ";;;; package.lisp~%")
  (format out ";;;; AUTO-GENERATED by cl-webgpu-codegen. Do not edit manually.~%")
  (format out ";;;; Run (cl-webgpu-codegen:generate) to regenerate.~%~%")
  (format out "(defpackage #:cl-webgpu~%")
  (format out "  (:use #:cl #:cffi)~%")
  (format out "  (:export~%")
  (let ((exports (collect-export-symbols ctx)))
    (loop for sym in exports
          for i from 0
          do (if (= i (1- (length exports)))
                 (format out "   #:~A))~%" sym)
                 (format out "   #:~A~%" sym)))))
