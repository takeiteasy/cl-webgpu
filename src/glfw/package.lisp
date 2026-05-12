;;;; src/glfw/package.lisp
;;;; Package definition for cl-webgpu/glfw GLFW integration

(defpackage #:cl-webgpu/glfw
  (:use #:cl #:cffi #:cl-webgpu)
  (:export
   ;; GLFW library loading
   #:load-glfw-libraries

   ;; GLFW functions
   #:glfw-init
   #:glfw-terminate
   #:glfw-window-hint
   #:glfw-create-window
   #:glfw-destroy-window
   #:glfw-window-should-close
   #:glfw-set-window-should-close
   #:glfw-poll-events
   #:glfw-get-window-size
   #:glfw-make-context-current
   #:glfw-swap-buffers
   #:glfw-swap-interval

   ;; GLFW constants
   #:+glfw-client-api+
   #:+glfw-no-api+
   #:+glfw-resizable+
   #:+glfw-true+
   #:+glfw-false+

   ;; GLFW types
   #:glfw-window

   ;; glfw3webgpu
   #:glfw-create-window-wgpu-surface
   ))
