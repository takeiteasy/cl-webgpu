;;;; package.lisp

(defpackage #:cl-webgpu
  (:use #:cl #:cffi)
  (:export
   ;; Opaque handle types
   #:wgpu-adapter
   #:wgpu-bind-group
   #:wgpu-bind-group-layout
   #:wgpu-buffer
   #:wgpu-command-buffer
   #:wgpu-command-encoder
   #:wgpu-compute-pass-encoder
   #:wgpu-compute-pipeline
   #:wgpu-device
   #:wgpu-instance
   #:wgpu-pipeline-layout
   #:wgpu-query-set
   #:wgpu-queue
   #:wgpu-render-bundle
   #:wgpu-render-bundle-encoder
   #:wgpu-render-pass-encoder
   #:wgpu-render-pipeline
   #:wgpu-sampler
   #:wgpu-shader-module
   #:wgpu-surface
   #:wgpu-texture
   #:wgpu-texture-view

   ;; Core functions
   #:wgpu-create-instance
   #:wgpu-get-instance-features
   #:wgpu-get-instance-limits
   #:wgpu-has-instance-feature
   #:wgpu-get-proc-address

    ;; Library loading
    #:load-wgpu-libraries

    ;; Shim utilities
    #:wgpu-shim-make-string-view
    ))
