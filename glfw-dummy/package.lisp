;;;; glfw-dummy/package.lisp

(defpackage #:cl-webgpu/glfw-dummy
  (:use #:cl #:cffi)
  (:export #:*frame-budget*
           #:initialize
           #:create-window
           #:window-should-close-p
           #:poll-events
           #:destroy-window
           #:terminate
           #:get-primary-monitor))
