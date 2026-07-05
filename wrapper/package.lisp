(defpackage #:cl-webgpu/wrapper
  (:use #:cl #:cffi)
  (:import-from #:cl-webgpu
   ;; opaque handle types
   #:wgpu-instance #:wgpu-adapter #:wgpu-device #:wgpu-surface
   #:wgpu-shader-module #:wgpu-render-pipeline #:wgpu-command-encoder
   #:wgpu-render-pass-encoder #:wgpu-texture-view #:wgpu-queue #:wgpu-buffer
   #:wgpu-texture #:wgpu-command-buffer
   ;; struct types
   #:wgpu-string-view #:wgpu-chained-struct
   #:wgpu-request-adapter-options #:wgpu-device-descriptor
   #:wgpu-queue-descriptor #:wgpu-device-lost-callback-info
   #:wgpu-uncaptured-error-callback-info #:wgpu-shader-source-wgsl
   #:wgpu-shader-module-descriptor #:wgpu-render-pipeline-descriptor
   #:wgpu-vertex-state #:wgpu-primitive-state #:wgpu-multisample-state
   #:wgpu-fragment-state #:wgpu-color-target-state
   #:wgpu-surface-configuration #:wgpu-surface-capabilities
   #:wgpu-command-encoder-descriptor #:wgpu-render-pass-descriptor
   #:wgpu-render-pass-color-attachment #:wgpu-color
   #:wgpu-command-buffer-descriptor #:wgpu-texture-view-descriptor
   #:wgpu-surface-texture
   ;; functions
   #:wgpu-create-instance #:wgpu-instance-release
   #:wgpu-shim-instance-request-adapter-sync #:wgpu-adapter-release
   #:wgpu-shim-adapter-request-device-sync #:wgpu-device-release
   #:wgpu-surface-unconfigure #:wgpu-surface-release
   #:wgpu-surface-get-capabilities #:wgpu-shim-surface-capabilities-free-members
   #:wgpu-device-create-shader-module #:wgpu-shader-module-release
   #:wgpu-device-create-render-pipeline #:wgpu-render-pipeline-release
   #:wgpu-surface-configure
   #:wgpu-device-create-command-encoder #:wgpu-command-encoder-release
   #:wgpu-command-encoder-begin-render-pass
   #:wgpu-render-pass-encoder-set-pipeline
   #:wgpu-render-pass-encoder-draw
   #:wgpu-render-pass-encoder-end #:wgpu-render-pass-encoder-release
   #:wgpu-command-encoder-finish #:wgpu-command-buffer-release
   #:wgpu-device-get-queue #:wgpu-queue-submit #:wgpu-queue-release
   #:wgpu-surface-get-current-texture #:wgpu-surface-present
   #:wgpu-texture-create-view #:wgpu-texture-view-release
   #:wgpu-buffer-destroy #:wgpu-buffer-release
   #:%get-silent-uncaptured-error-callback
   ;; enums used as CFFI types in wrapper
   #:wgpu-texture-format
   ;; constants
   #:+wgpu-texture-usage-render-attachment+
   ;; struct slot names — now exported from cl-webgpu (ticket #18 resolved)
   #:next-in-chain #:next #:s-type
   #:data #:length
   #:label #:code #:chain
   #:power-preference #:feature-level #:force-fallback-adapter
   #:backend-type #:compatible-surface
   #:required-feature-count #:required-features #:required-limits
   #:default-queue #:device-lost-callback-info #:uncaptured-error-callback-info
   #:callback #:userdata #:userdata1 #:userdata2 #:mode #:device
   #:module #:entry-point #:constant-count #:constants
   #:buffer-count #:buffers #:vertex #:primitive #:multisample #:depth-stencil
   #:fragment #:target-count #:targets
   #:topology #:strip-index-format #:front-face #:cull-mode #:unclipped-depth
   #:count #:mask #:alpha-to-coverage-enabled
   #:format #:blend #:write-mask
   #:usage #:width #:height #:present-mode #:alpha-mode
   #:view-format-count #:view-formats #:layout
   #:load-op #:store-op #:clear-value #:r #:g #:b #:a
   #:resolve-target #:depth-slice #:view
   #:color-attachment-count #:color-attachments
   #:occlusion-query-set #:depth-stencil-attachment #:timestamp-writes
   #:format-count #:formats)
  (:export
   ;; base class + generics
   #:gpu-handle #:handle #:release #:null-handle-p
   ;; handle classes
   #:gpu-instance #:gpu-adapter #:gpu-device #:gpu-surface
   #:gpu-shader-module #:gpu-render-pipeline #:gpu-command-encoder
   #:gpu-render-pass #:gpu-texture-view #:gpu-queue #:gpu-buffer
   ;; scoped struct helper
   #:with-wgpu-struct
   ;; with-X macros
   #:with-gpu-instance #:with-gpu-adapter #:with-gpu-device
   #:with-gpu-shader-module #:with-gpu-render-pipeline
   #:with-gpu-command-encoder #:with-render-pass
   ;; creation helpers
   #:make-gpu-instance
   #:request-gpu-adapter
   #:request-gpu-device
   #:make-shader-module
   #:get-surface-format
   #:make-render-pipeline
   #:configure-surface
   #:make-command-encoder
   #:begin-render-pass
   #:end-and-submit))
