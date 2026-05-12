;;;; library.lisp
;;;; CFFI foreign library definitions for cl-webgpu

(in-package #:cl-webgpu)

;; ============================================================================
;; Foreign library definitions
;; ============================================================================

(define-foreign-library wgpu-native
  (:darwin (:or "libwgpu_native.dylib" "wgpu_native.dylib"))
  (:unix (:or "libwgpu_native.so" "wgpu_native.so"))
  (:windows (:or "wgpu_native.dll" "libwgpu_native.dll"))
  (t (:default "libwgpu_native")))

(define-foreign-library webgpu-shim
  (:darwin (:or "libwebgpu_shim.dylib" "webgpu_shim.dylib"))
  (:unix (:or "libwebgpu_shim.so" "webgpu_shim.so"))
  (:windows (:or "webgpu_shim.dll" "libwebgpu_shim.dll"))
  (t (:default "libwebgpu_shim")))

(defun load-wgpu-libraries (&key wgpu-path shim-path)
  "Load the wgpu-native and shim libraries.

If WGPU-PATH is provided, it should be the path to the wgpu-native shared
library (or the directory containing it).

If SHIM-PATH is provided, it should be the path to the shim shared library.

You may need to call this before using any WebGPU functions."
  (when wgpu-path
    (pushnew wgpu-path cffi:*foreign-library-directories*))
  (when shim-path
    (pushnew shim-path cffi:*foreign-library-directories*))
  ;; Load wgpu-native first so the shim can resolve its symbols
  (load-foreign-library 'wgpu-native)
  (load-foreign-library 'webgpu-shim))
