;;;; src/glfw/library.lisp

(in-package #:cl-webgpu/glfw)

(cffi:define-foreign-library glfw3webgpu
  (:darwin (:or "libglfw3webgpu.dylib" "glfw3webgpu.dylib"))
  (:unix (:or "libglfw3webgpu.so" "glfw3webgpu.so"))
  (t (:default "libglfw3webgpu")))

(defun load-glfw-library (&key path)
  "Push PATH onto cffi:*foreign-library-directories* and load libglfw3webgpu.
   cl-glfw3 handles loading GLFW itself; we only need the glfw3webgpu bridge."
  (when path
    (pushnew path cffi:*foreign-library-directories* :test #'equal))
  (cffi:load-foreign-library 'glfw3webgpu))

(cffi:defcfun ("glfwCreateWindowWGPUSurface" glfw-create-window-wgpu-surface)
    cl-webgpu:wgpu-surface
  (instance cl-webgpu:wgpu-instance)
  (window %glfw::window))
