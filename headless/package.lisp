;;;; headless/package.lisp

(defpackage #:cl-webgpu/headless
  (:use #:cl #:cffi #:cl-webgpu/wrapper)
  (:import-from #:cl-webgpu
   ;; struct types
   #:wgpu-texel-copy-buffer-info #:wgpu-texel-copy-buffer-layout
   #:wgpu-texel-copy-texture-info #:wgpu-origin3-d
   #:wgpu-texture-view-descriptor #:wgpu-extent3-d
   #:wgpu-command-buffer #:wgpu-command-buffer-descriptor #:wgpu-future
   ;; slot names for texel-copy structs
   #:texture #:buffer #:aspect #:mip-level #:origin #:layout
   #:offset #:next-in-chain #:bytes-per-row
   ;; functions not re-exported by cl-webgpu/wrapper
   #:wgpu-texture-create-view
   #:wgpu-command-encoder-finish #:wgpu-command-buffer-release
   #:wgpu-queue-submit
   ;; slot names not already re-exported by cl-webgpu/wrapper
   #:x #:y #:z #:rows-per-image
   #:mip-level-count #:array-layer-count #:width #:height #:depth-or-array-layers
   ;; low-level functions
   #:wgpu-command-encoder-copy-texture-to-buffer
   #:wgpu-buffer-map-async #:wgpu-buffer-get-mapped-range #:wgpu-buffer-unmap
   #:wgpu-device-poll
   ;; enums used as CFFI types
   #:wgpu-map-async-status #:wgpu-callback-mode
   ;; constants
   #:+wgpu-texture-usage-copy-src+
   #:+wgpu-texture-usage-render-attachment+
   #:+wgpu-buffer-usage-map-read+
   #:+wgpu-buffer-usage-copy-dst+)
  (:export
   #:gpu-offscreen-target
   #:make-offscreen-target
   #:offscreen-target-width
   #:offscreen-target-height
   #:readback-texture-png))
