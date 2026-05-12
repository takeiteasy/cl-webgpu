;;;; src/glfw/bindings.lisp
;;;; CFFI foreign function bindings for GLFW and glfw3webgpu

(in-package #:cl-webgpu/glfw)

;; ============================================================================
;; GLFW constants
;; ============================================================================

(defconstant +glfw-true+ 1)
(defconstant +glfw-false+ 0)
(defconstant +glfw-resizable+ #x00020003)
(defconstant +glfw-client-api+ #x00022001)
(defconstant +glfw-no-api+ 0)

;; ============================================================================
;; GLFW types
;; ============================================================================

(defctype glfw-window :pointer)

;; ============================================================================
;; GLFW functions
;; ============================================================================

(defcfun ("glfwInit" glfw-init) :int)

(defcfun ("glfwTerminate" glfw-terminate) :void)

(defcfun ("glfwWindowHint" glfw-window-hint) :void
  (hint :int)
  (value :int))

(defcfun ("glfwCreateWindow" glfw-create-window) glfw-window
  (width :int)
  (height :int)
  (title :string)
  (monitor :pointer)
  (share :pointer))

(defcfun ("glfwDestroyWindow" glfw-destroy-window) :void
  (window glfw-window))

(defcfun ("glfwWindowShouldClose" glfw-window-should-close) :int
  (window glfw-window))

(defcfun ("glfwSetWindowShouldClose" glfw-set-window-should-close) :void
  (window glfw-window)
  (value :int))

(defcfun ("glfwPollEvents" glfw-poll-events) :void)

(defcfun ("glfwGetWindowSize" glfw-get-window-size) :void
  (window glfw-window)
  (width (:pointer :int))
  (height (:pointer :int)))

(defcfun ("glfwMakeContextCurrent" glfw-make-context-current) :void
  (window glfw-window))

(defcfun ("glfwSwapBuffers" glfw-swap-buffers) :void
  (window glfw-window))

(defcfun ("glfwSwapInterval" glfw-swap-interval) :void
  (interval :int))

;; ============================================================================
;; glfw3webgpu functions
;; ============================================================================

(defcfun ("glfwCreateWindowWGPUSurface" glfw-create-window-wgpu-surface) wgpu-surface
  (instance wgpu-instance)
  (window glfw-window))

;; Export all symbols defined in this package
(let ((pkg (find-package :cl-webgpu/glfw)))
  (do-symbols (sym pkg)
    (when (eq (symbol-package sym) pkg)
      (export sym pkg))))
