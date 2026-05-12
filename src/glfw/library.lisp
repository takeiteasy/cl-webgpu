;;;; src/glfw/library.lisp
;;;; CFFI foreign library definitions for GLFW and glfw3webgpu

(in-package #:cl-webgpu/glfw)

;; ============================================================================
;; Foreign library definitions
;; ============================================================================

(define-foreign-library glfw
  (:darwin (:or "libglfw.3.dylib" "libglfw3.dylib" "glfw3.dylib"))
  (:unix (:or "libglfw.so.3" "libglfw.so" "glfw.so.3"))
  (:windows (:or "glfw3.dll" "glfw.dll"))
  (t (:default "libglfw")))

(define-foreign-library glfw3webgpu
  (:darwin (:or "libglfw3webgpu.dylib" "glfw3webgpu.dylib"))
  (:unix (:or "libglfw3webgpu.so" "glfw3webgpu.so"))
  (:windows (:or "glfw3webgpu.dll" "libglfw3webgpu.dll"))
  (t (:default "libglfw3webgpu")))

(defun load-glfw-libraries (&key glfw-path glfw3webgpu-path)
  "Load the GLFW and glfw3webgpu shared libraries.

If GLFW-PATH is provided, it should be the path to the GLFW shared
library (or the directory containing it).

If GLFW3WEBGPU-PATH is provided, it should be the path to the
glfw3webgpu shared library."
  (when glfw-path
    (pushnew glfw-path cffi:*foreign-library-directories*))
  (when glfw3webgpu-path
    (pushnew glfw3webgpu-path cffi:*foreign-library-directories*))
  (load-foreign-library 'glfw)
  (load-foreign-library 'glfw3webgpu))
