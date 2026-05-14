;;;; src/glfw/package.lisp

(defpackage #:cl-webgpu/glfw
  (:use #:cl #:cffi)
  (:export #:load-glfw-library
           #:glfw-create-window-wgpu-surface))
