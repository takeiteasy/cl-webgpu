;;;; codegen/name-transformer.lisp
;;;; Converts C identifiers to Lisp naming conventions.

(in-package #:cl-webgpu-codegen)

(defun camel-case-to-kebab (s)
  "Convert a CamelCase or mixedCase string to kebab-case.
  Examples: WGPUFoo -> wgpu-foo, DiscreteGPU -> discrete-gpu, D3D12 -> d3-d12"
  (let ((result '())
        (len (length s)))
    (dotimes (i len)
      (let* ((ch (char s i))
             (prev (when (> i 0) (char s (1- i))))
             (next (when (< i (1- len)) (char s (1+ i)))))
        (cond
          ((upper-case-p ch)
           (when (and prev
                      (or (lower-case-p prev)
                          (digit-char-p prev)
                          (and (upper-case-p prev)
                               next
                               (lower-case-p next))))
             (push #\- result))
           (push (char-downcase ch) result))
          (t
           (push ch result)))))
    (coerce (nreverse result) 'string)))

(defun split-by-char (s ch)
  "Split string S on character CH, discarding empty segments."
  (let ((result '())
        (start 0))
    (dotimes (i (length s))
      (when (char= (char s i) ch)
        (when (< start i)
          (push (subseq s start i) result))
        (setf start (1+ i))))
    (when (< start (length s))
      (push (subseq s start) result))
    (nreverse result)))

(defun convert-segment (seg)
  "Convert one underscore-separated segment to kebab-case.
  Strips the leading WGPU/wgpu prefix first so that the remainder is
  processed independently: WGPUSType -> wgpu-s-type (not wgpus-type),
  WGPUWGSLFoo -> wgpu-wgsl-foo."
  (if (and (>= (length seg) 4)
           (string-equal (subseq seg 0 4) "WGPU"))
      (let ((rest (subseq seg 4)))
        (if (string= rest "")
            "wgpu"
            (concatenate 'string "wgpu-" (camel-case-to-kebab rest))))
      (camel-case-to-kebab seg)))

(defun c-name-to-lisp-symbol (name)
  "Convert a C identifier to a Lisp symbol name string.
  Strips the WGPU/wgpu prefix and processes the remainder independently.
  Examples:
    WGPUAdapterType             -> wgpu-adapter-type
    WGPUSType                   -> wgpu-s-type
    WGPUWGSLLanguageFeatureName -> wgpu-wgsl-language-feature-name
    wgpuAdapterGetInfo          -> wgpu-adapter-get-info
    WGPUBufferUsage_MapRead     -> wgpu-buffer-usage-map-read
    WGPU_BUFFER_USAGE_MAP_READ  -> wgpu-buffer-usage-map-read"
  (let ((segments (split-by-char name #\_)))
    (format nil "~{~A~^-~}" (mapcar #'convert-segment segments))))

(defun c-enum-value-to-keyword-string (type-name value-name)
  "Strip the type prefix and convert to a keyword string.
  Example: (c-enum-value-to-keyword-string \"WGPUAdapterType\" \"WGPUAdapterType_DiscreteGPU\")
           -> \"discrete-gpu\""
  (let* ((prefix (concatenate 'string type-name "_"))
         (stripped (if (and (>= (length value-name) (length prefix))
                            (string= value-name prefix
                                     :end1 (length prefix)
                                     :end2 (length prefix)))
                       (subseq value-name (length prefix))
                       value-name)))
    (camel-case-to-kebab stripped)))

(defun c-flag-name-to-constant-string (flag-name)
  "Convert a C flag constant name to a Lisp +constant+ string.
  Example: WGPUBufferUsage_MapRead -> +wgpu-buffer-usage-map-read+"
  (format nil "+~A+" (c-name-to-lisp-symbol flag-name)))

(defun c-field-name-to-symbol (field-name)
  "Convert a camelCase C field name to a Lisp symbol name.
  Example: nextInChain -> next-in-chain"
  (camel-case-to-kebab field-name))

(defun c-type-name-to-symbol (type-name)
  "Convert a C type name to its Lisp symbol string.
  Example: WGPUBufferDescriptor -> wgpu-buffer-descriptor"
  (c-name-to-lisp-symbol type-name))
