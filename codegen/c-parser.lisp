;;;; codegen/c-parser.lisp
;;;; Parses webgpu.h and wgpu.h C headers into structured data.
;;;; Uses batch cl-ppcre scanning (one pass per construct type) for performance.

(in-package #:cl-webgpu/codegen)

;;; Parse context

(defstruct parse-context
  (opaque-handles (make-hash-table :test #'equal))
  (enum-types     (make-hash-table :test #'equal))
  (struct-types   (make-hash-table :test #'equal))
  (flag-types     (make-hash-table :test #'equal))
  (declarations   '()))

;;; Comment stripping

(defun strip-c-comments (text)
  "Remove /* */ and // comments, preserving newlines for line-tracking."
  (with-output-to-string (out)
    (let ((i 0) (len (length text)) (state :normal))
      (loop while (< i len) do
        (let ((ch (char text i))
              (next (when (< (1+ i) len) (char text (1+ i)))))
          (case state
            (:normal
             (cond ((and (char= ch #\/) (eql next #\*))
                    (setf state :block) (incf i 2))
                   ((and (char= ch #\/) (eql next #\/))
                    (setf state :line) (incf i 2))
                   (t (write-char ch out) (incf i))))
            (:block
             (cond ((and (char= ch #\*) (eql next #\/))
                    (setf state :normal) (write-char #\space out) (incf i 2))
                   ((char= ch #\newline)
                    (write-char #\newline out) (incf i))
                   (t (incf i))))
            (:line
             (cond ((char= ch #\newline)
                    (setf state :normal) (write-char #\newline out) (incf i))
                   (t (incf i))))))))))

;;; Utilities

(defun find-matching-close-brace (text open-pos)
  "Return position just past the } matching the { at OPEN-POS."
  (let ((depth 0))
    (loop for i from open-pos below (length text)
          do (let ((ch (char text i)))
               (cond ((char= ch #\{) (incf depth))
                     ((char= ch #\}) (decf depth)
                      (when (= depth 0)
                        (return-from find-matching-close-brace (1+ i))))))
          finally (return nil))))

(defun skip-to-after-semicolon (text start)
  (let ((p (position #\; text :start start)))
    (if p (1+ p) (length text))))

(defun parse-hex-or-decimal (s)
  (let ((s (string-trim '(#\space #\tab #\( #\)) s)))
    (cond ((cl-ppcre:scan "^0[xX]" s)
           (parse-integer s :start 2 :radix 16 :junk-allowed t))
          (t (parse-integer s :junk-allowed t)))))

(defun pointer-type-p (type-str)
  (position #\* type-str))

(defun base-type (type-str)
  "Strip *, const, struct, WGPU_NULLABLE from a type string."
  (let ((s type-str))
    (dolist (p '("WGPU_NULLABLE" "\\bconst\\b" "\\bstruct\\b" "\\*"))
      (setf s (cl-ppcre:regex-replace-all p s "")))
    (string-trim '(#\space #\tab) s)))

;;; Sub-structure parsers

(defun parse-enum-values (body)
  (let (values)
    (cl-ppcre:do-register-groups (name val-str)
        ("(\\w+)\\s*=\\s*(0[xX][0-9A-Fa-f]+|\\d+)" body)
      (unless (cl-ppcre:scan "Force3[26]$" name)
        (let ((v (parse-hex-or-decimal val-str)))
          (when v (push (cons name v) values)))))
    (nreverse values)))

(defun parse-struct-fields (body)
  (let (fields)
    (cl-ppcre:do-register-groups (type-part star field-name)
        ("(?:WGPU_NULLABLE\\s+)?(?:const\\s+)?(?:struct\\s+)?(\\w+)\\s*(\\*?)\\s*(\\w+)\\s*;" body)
      (unless (member type-part '("typedef" "struct" "enum" "if" "else" "return")
                      :test #'string=)
        (push (list :name field-name :ctype (concatenate 'string type-part star)) fields)))
    (nreverse fields)))

(defun parse-params (params-str)
  (let* ((s (string-trim '(#\space #\tab #\newline) params-str)))
    (when (or (string= s "") (string= s "void"))
      (return-from parse-params nil))
    (remove nil
            (mapcar (lambda (p)
                      (let* ((p (cl-ppcre:regex-replace-all "WGPU_NULLABLE\\s*" p ""))
                             (p (string-trim '(#\space #\tab) p)))
                        (if (or (string= p "") (string= s "void"))
                            nil
                            (cl-ppcre:register-groups-bind (type-part pname)
                                ("^(.+[\\*\\s])\\s*(\\w+)\\s*$" p)
                              (list :name pname
                                    :ctype (string-trim '(#\space #\tab) type-part))))))
                    (cl-ppcre:split "\\s*,\\s*" s)))))

;;; Batch scanners — one pass per construct type

(defun scan-opaque-handles (text ctx)
  (cl-ppcre:do-register-groups (name)
      ("typedef\\s+struct\\s+\\w+Impl\\s*\\*\\s*(\\w+)\\s+WGPU_OBJECT_ATTRIBUTE\\s*;" text)
    (unless (gethash name (parse-context-opaque-handles ctx))
      (setf (gethash name (parse-context-opaque-handles ctx)) t)
      (push (list :kind :opaque :name name) (parse-context-declarations ctx)))))

(defun scan-enums (text ctx)
  (let ((pos 0))
    (loop
      (multiple-value-bind (s e rs re)
          (cl-ppcre:scan "typedef\\s+enum\\s+(\\w+)\\s*\\{" text :start pos)
        (unless s (return))
        (let* ((type-name  (subseq text (aref rs 0) (aref re 0)))
               (open-brace (1- e))
               (close-pos  (find-matching-close-brace text open-brace))
               (end-pos    (if close-pos (skip-to-after-semicolon text close-pos) e))
               (body       (when close-pos (subseq text (1+ open-brace) (1- close-pos))))
               (vals       (when body (parse-enum-values body))))
          (unless (gethash type-name (parse-context-enum-types ctx))
            (setf (gethash type-name (parse-context-enum-types ctx)) t)
            (push (list :kind :enum :name type-name :values vals)
                  (parse-context-declarations ctx)))
          (setf pos end-pos))))))

(defun scan-flag-types (text ctx)
  (cl-ppcre:do-register-groups (name)
      ("typedef\\s+WGPUFlags\\s+(\\w+)\\s*;" text)
    (unless (gethash name (parse-context-flag-types ctx))
      (setf (gethash name (parse-context-flag-types ctx)) t)
      (push (list :kind :flag-type :name name) (parse-context-declarations ctx)))))

(defun scan-flag-values (text ctx)
  (cl-ppcre:do-register-groups (flag-type flag-name val-str)
      ("static\\s+const\\s+(\\w+)\\s+(\\w+)\\s*=\\s*(0[xX][0-9A-Fa-f]+|\\d+)\\s*;" text)
    (when (and (gethash flag-type (parse-context-flag-types ctx))
               (not (cl-ppcre:scan "Force3[26]$" flag-name)))
      (let ((val (parse-hex-or-decimal val-str)))
        (push (list :kind :flag-value :flag-type flag-type :name flag-name :value val)
              (parse-context-declarations ctx))))))

(defun scan-structs (text ctx)
  (let ((pos 0))
    (loop
      (multiple-value-bind (s e rs re)
          (cl-ppcre:scan "typedef\\s+struct\\s+(\\w+)\\s*\\{" text :start pos)
        (unless s (return))
        (let* ((type-name  (subseq text (aref rs 0) (aref re 0)))
               (open-brace (1- e))
               (close-pos  (find-matching-close-brace text open-brace))
               (end-pos    (if close-pos (skip-to-after-semicolon text close-pos) (1+ s)))
               (body       (when close-pos (subseq text (1+ open-brace) (1- close-pos))))
               (fields     (when body (parse-struct-fields body))))
          ;; Don't overwrite opaque handles that happen to match typedef struct pattern
          (unless (or (gethash type-name (parse-context-opaque-handles ctx))
                      (gethash type-name (parse-context-struct-types ctx)))
            (setf (gethash type-name (parse-context-struct-types ctx)) t)
            (push (list :kind :struct :name type-name :fields fields)
                  (parse-context-declarations ctx)))
          (setf pos end-pos))))))

(defun scan-callbacks (text ctx)
  (declare (ignore ctx))
  ;; Only collect callback names for documentation; callbacks map to :pointer
  ;; We don't emit them in types.lisp since they're handled as :pointer
  (cl-ppcre:do-register-groups (name)
      ("typedef\\s+\\w+[\\s\\*]*\\(\\s*\\*\\s*(WGPU\\w+)\\s*\\)\\s*\\([^)]*\\)[^;]*;" text)
    (declare (ignore name))
    nil))

(defun scan-wgpu-export-functions (text ctx)
  "Scan for WGPU_EXPORT function declarations (webgpu.h style)."
  (cl-ppcre:do-register-groups (ret name pars)
      ("WGPU_EXPORT\\s+(\\w[\\w\\s\\*]*)\\s+(wgpu\\w+)\\s*\\(([^)]*)\\)\\s*WGPU_FUNCTION_ATTRIBUTE\\s*;" text)
    (let ((ret (string-trim '(#\space #\tab) ret)))
      (push (list :kind :function :name name :return-type ret :params (parse-params pars))
            (parse-context-declarations ctx)))))

(defun scan-native-functions (text ctx)
  "Scan for wgpu.h native extension functions (inside extern C, indented, no WGPU_EXPORT)."
  ;; Pattern: line starting with 1+ spaces, then RetType wgpuFoo(...);
  ;; Non-greedy on return type to handle void* returns with no space before name.
  (cl-ppcre:do-register-groups (ret name pars)
      ("(?m)^[ \\t]+([\\w\\s\\*]+?)\\s*(wgpu\\w+)\\s*\\(([^)]*)\\)\\s*;" text)
    (let ((ret (string-trim '(#\space #\tab) ret)))
      ;; Only add if not already present (webgpu.h may have same functions via WGPU_EXPORT)
      (push (list :kind :function :name name :return-type ret :params (parse-params pars))
            (parse-context-declarations ctx)))))

;;; Main entry point

(defun deduplicate-functions (decls)
  "Remove duplicate function declarations (keep first occurrence by C name)."
  (let ((seen (make-hash-table :test #'equal))
        result)
    (dolist (d (reverse decls))
      (if (eq (getf d :kind) :function)
          (let ((name (getf d :name)))
            (unless (gethash name seen)
              (setf (gethash name seen) t)
              (push d result)))
          (push d result)))
    result))

(defun parse-header-text (text ctx)
  "Parse a comment-stripped C header, populating CTX with declarations."
  ;; Order matters here: opaque handles and enums must be registered before
  ;; struct scanning so the type context is correct.
  (scan-opaque-handles text ctx)
  (scan-enums text ctx)
  (scan-flag-types text ctx)
  (scan-flag-values text ctx)
  (scan-structs text ctx)
  (scan-callbacks text ctx)
  (scan-wgpu-export-functions text ctx)
  (scan-native-functions text ctx))

(defun parse-headers (webgpu-h-path wgpu-h-path)
  "Parse both WebGPU C headers. Returns a populated parse-context."
  (let ((ctx (make-parse-context)))
    (dolist (path (list webgpu-h-path wgpu-h-path))
      (let* ((text     (uiop:read-file-string path))
             (stripped (strip-c-comments text)))
        (parse-header-text stripped ctx)))
    ;; Reverse to restore reading order, then deduplicate functions
    (setf (parse-context-declarations ctx)
          (deduplicate-functions
           (nreverse (parse-context-declarations ctx))))
    ctx))
