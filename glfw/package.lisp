;;;; src/glfw/package.lisp

(defpackage #:cl-webgpu/glfw
  (:use #:cl #:cffi)
  (:export #:load-glfw-library
           #:glfw-create-window-wgpu-surface))

;; Forward-export every external symbol from cl-glfw3 so callers can use
;; cl-webgpu/glfw as a drop-in replacement (no direct cl-glfw3 dependency).
(eval-when (:compile-toplevel :load-toplevel :execute)
  (do-external-symbols (s :cl-glfw3)
    (import s :cl-webgpu/glfw)
    (export s :cl-webgpu/glfw)))
