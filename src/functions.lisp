;;;; functions.lisp
;;;; CFFI foreign function bindings for WebGPU

(in-package #:cl-webgpu)

;; ============================================================================
;; Core webgpu.h functions (pointer-based parameters, no struct-by-value)
;; These are bound directly from wgpu-native.
;; ============================================================================

;; Instance
(defcfun ("wgpuCreateInstance" wgpu-create-instance) wgpu-instance
  (descriptor :pointer))

(defcfun ("wgpuGetInstanceFeatures" wgpu-get-instance-features) :void
  (features :pointer))

(defcfun ("wgpuGetInstanceLimits" wgpu-get-instance-limits) wgpu-status
  (limits :pointer))

(defcfun ("wgpuHasInstanceFeature" wgpu-has-instance-feature) wgpu-bool
  (feature wgpu-instance-feature-name))

;; Adapter
(defcfun ("wgpuAdapterGetFeatures" wgpu-adapter-get-features) :void
  (adapter wgpu-adapter)
  (features :pointer))

(defcfun ("wgpuAdapterGetInfo" wgpu-adapter-get-info) wgpu-status
  (adapter wgpu-adapter)
  (info :pointer))

(defcfun ("wgpuAdapterGetLimits" wgpu-adapter-get-limits) wgpu-status
  (adapter wgpu-adapter)
  (limits :pointer))

(defcfun ("wgpuAdapterHasFeature" wgpu-adapter-has-feature) wgpu-bool
  (adapter wgpu-adapter)
  (feature wgpu-feature-name))

(defcfun ("wgpuAdapterAddRef" wgpu-adapter-add-ref) :void
  (adapter wgpu-adapter))

(defcfun ("wgpuAdapterRelease" wgpu-adapter-release) :void
  (adapter wgpu-adapter))

;; BindGroup
(defcfun ("wgpuBindGroupAddRef" wgpu-bind-group-add-ref) :void
  (bind-group wgpu-bind-group))

(defcfun ("wgpuBindGroupRelease" wgpu-bind-group-release) :void
  (bind-group wgpu-bind-group))

;; BindGroupLayout
(defcfun ("wgpuBindGroupLayoutAddRef" wgpu-bind-group-layout-add-ref) :void
  (bind-group-layout wgpu-bind-group-layout))

(defcfun ("wgpuBindGroupLayoutRelease" wgpu-bind-group-layout-release) :void
  (bind-group-layout wgpu-bind-group-layout))

;; Buffer
(defcfun ("wgpuBufferDestroy" wgpu-buffer-destroy) :void
  (buffer wgpu-buffer))

(defcfun ("wgpuBufferGetConstMappedRange" wgpu-buffer-get-const-mapped-range) :pointer
  (buffer wgpu-buffer)
  (offset :size)
  (size :size))

(defcfun ("wgpuBufferGetMapState" wgpu-buffer-get-map-state) wgpu-buffer-map-state
  (buffer wgpu-buffer))

(defcfun ("wgpuBufferGetMappedRange" wgpu-buffer-get-mapped-range) :pointer
  (buffer wgpu-buffer)
  (offset :size)
  (size :size))

(defcfun ("wgpuBufferGetSize" wgpu-buffer-get-size) :uint64
  (buffer wgpu-buffer))

(defcfun ("wgpuBufferGetUsage" wgpu-buffer-get-usage) wgpu-flags
  (buffer wgpu-buffer))

;; Note: wgpuBufferSetLabel takes WGPUStringView by value - use shim
;; (defcfun ("wgpuBufferSetLabel" wgpu-buffer-set-label) ...)

(defcfun ("wgpuBufferUnmap" wgpu-buffer-unmap) :void
  (buffer wgpu-buffer))

(defcfun ("wgpuBufferAddRef" wgpu-buffer-add-ref) :void
  (buffer wgpu-buffer))

(defcfun ("wgpuBufferRelease" wgpu-buffer-release) :void
  (buffer wgpu-buffer))

;; CommandBuffer
(defcfun ("wgpuCommandBufferAddRef" wgpu-command-buffer-add-ref) :void
  (command-buffer wgpu-command-buffer))

(defcfun ("wgpuCommandBufferRelease" wgpu-command-buffer-release) :void
  (command-buffer wgpu-command-buffer))

;; CommandEncoder
(defcfun ("wgpuCommandEncoderBeginComputePass" wgpu-command-encoder-begin-compute-pass) wgpu-compute-pass-encoder
  (command-encoder wgpu-command-encoder)
  (descriptor :pointer))

(defcfun ("wgpuCommandEncoderBeginRenderPass" wgpu-command-encoder-begin-render-pass) wgpu-render-pass-encoder
  (command-encoder wgpu-command-encoder)
  (descriptor :pointer))

(defcfun ("wgpuCommandEncoderClearBuffer" wgpu-command-encoder-clear-buffer) :void
  (command-encoder wgpu-command-encoder)
  (buffer wgpu-buffer)
  (offset :uint64)
  (size :uint64))

(defcfun ("wgpuCommandEncoderCopyBufferToBuffer" wgpu-command-encoder-copy-buffer-to-buffer) :void
  (command-encoder wgpu-command-encoder)
  (source wgpu-buffer)
  (source-offset :uint64)
  (destination wgpu-buffer)
  (destination-offset :uint64)
  (size :uint64))

(defcfun ("wgpuCommandEncoderCopyBufferToTexture" wgpu-command-encoder-copy-buffer-to-texture) :void
  (command-encoder wgpu-command-encoder)
  (source :pointer)
  (destination :pointer)
  (copy-size :pointer))

(defcfun ("wgpuCommandEncoderCopyTextureToBuffer" wgpu-command-encoder-copy-texture-to-buffer) :void
  (command-encoder wgpu-command-encoder)
  (source :pointer)
  (destination :pointer)
  (copy-size :pointer))

(defcfun ("wgpuCommandEncoderCopyTextureToTexture" wgpu-command-encoder-copy-texture-to-texture) :void
  (command-encoder wgpu-command-encoder)
  (source :pointer)
  (destination :pointer)
  (copy-size :pointer))

(defcfun ("wgpuCommandEncoderFinish" wgpu-command-encoder-finish) wgpu-command-buffer
  (command-encoder wgpu-command-encoder)
  (descriptor :pointer))

(defcfun ("wgpuCommandEncoderPopDebugGroup" wgpu-command-encoder-pop-debug-group) :void
  (command-encoder wgpu-command-encoder))

(defcfun ("wgpuCommandEncoderResolveQuerySet" wgpu-command-encoder-resolve-query-set) :void
  (command-encoder wgpu-command-encoder)
  (query-set wgpu-query-set)
  (first-query :uint32)
  (query-count :uint32)
  (destination wgpu-buffer)
  (destination-offset :uint64))

(defcfun ("wgpuCommandEncoderWriteTimestamp" wgpu-command-encoder-write-timestamp) :void
  (command-encoder wgpu-command-encoder)
  (query-set wgpu-query-set)
  (query-index :uint32))

(defcfun ("wgpuCommandEncoderAddRef" wgpu-command-encoder-add-ref) :void
  (command-encoder wgpu-command-encoder))

(defcfun ("wgpuCommandEncoderRelease" wgpu-command-encoder-release) :void
  (command-encoder wgpu-command-encoder))

;; ComputePassEncoder
(defcfun ("wgpuComputePassEncoderDispatchWorkgroups" wgpu-compute-pass-encoder-dispatch-workgroups) :void
  (compute-pass-encoder wgpu-compute-pass-encoder)
  (workgroup-count-x :uint32)
  (workgroup-count-y :uint32)
  (workgroup-count-z :uint32))

(defcfun ("wgpuComputePassEncoderDispatchWorkgroupsIndirect" wgpu-compute-pass-encoder-dispatch-workgroups-indirect) :void
  (compute-pass-encoder wgpu-compute-pass-encoder)
  (indirect-buffer wgpu-buffer)
  (indirect-offset :uint64))

(defcfun ("wgpuComputePassEncoderEnd" wgpu-compute-pass-encoder-end) :void
  (compute-pass-encoder wgpu-compute-pass-encoder))

(defcfun ("wgpuComputePassEncoderPopDebugGroup" wgpu-compute-pass-encoder-pop-debug-group) :void
  (compute-pass-encoder wgpu-compute-pass-encoder))

(defcfun ("wgpuComputePassEncoderSetBindGroup" wgpu-compute-pass-encoder-set-bind-group) :void
  (compute-pass-encoder wgpu-compute-pass-encoder)
  (group-index :uint32)
  (group wgpu-bind-group)
  (dynamic-offset-count :size)
  (dynamic-offsets :pointer))

(defcfun ("wgpuComputePassEncoderSetPipeline" wgpu-compute-pass-encoder-set-pipeline) :void
  (compute-pass-encoder wgpu-compute-pass-encoder)
  (pipeline wgpu-compute-pipeline))

(defcfun ("wgpuComputePassEncoderAddRef" wgpu-compute-pass-encoder-add-ref) :void
  (compute-pass-encoder wgpu-compute-pass-encoder))

(defcfun ("wgpuComputePassEncoderRelease" wgpu-compute-pass-encoder-release) :void
  (compute-pass-encoder wgpu-compute-pass-encoder))

;; ComputePipeline
(defcfun ("wgpuComputePipelineGetBindGroupLayout" wgpu-compute-pipeline-get-bind-group-layout) wgpu-bind-group-layout
  (compute-pipeline wgpu-compute-pipeline)
  (group-index :uint32))

(defcfun ("wgpuComputePipelineAddRef" wgpu-compute-pipeline-add-ref) :void
  (compute-pipeline wgpu-compute-pipeline))

(defcfun ("wgpuComputePipelineRelease" wgpu-compute-pipeline-release) :void
  (compute-pipeline wgpu-compute-pipeline))

;; Device
(defcfun ("wgpuDeviceCreateBindGroup" wgpu-device-create-bind-group) wgpu-bind-group
  (device wgpu-device)
  (descriptor :pointer))

(defcfun ("wgpuDeviceCreateBindGroupLayout" wgpu-device-create-bind-group-layout) wgpu-bind-group-layout
  (device wgpu-device)
  (descriptor :pointer))

(defcfun ("wgpuDeviceCreateBuffer" wgpu-device-create-buffer) wgpu-buffer
  (device wgpu-device)
  (descriptor :pointer))

(defcfun ("wgpuDeviceCreateCommandEncoder" wgpu-device-create-command-encoder) wgpu-command-encoder
  (device wgpu-device)
  (descriptor :pointer))

(defcfun ("wgpuDeviceCreateComputePipeline" wgpu-device-create-compute-pipeline) wgpu-compute-pipeline
  (device wgpu-device)
  (descriptor :pointer))

(defcfun ("wgpuDeviceCreatePipelineLayout" wgpu-device-create-pipeline-layout) wgpu-pipeline-layout
  (device wgpu-device)
  (descriptor :pointer))

(defcfun ("wgpuDeviceCreateQuerySet" wgpu-device-create-query-set) wgpu-query-set
  (device wgpu-device)
  (descriptor :pointer))

(defcfun ("wgpuDeviceCreateRenderBundleEncoder" wgpu-device-create-render-bundle-encoder) wgpu-render-bundle-encoder
  (device wgpu-device)
  (descriptor :pointer))

(defcfun ("wgpuDeviceCreateRenderPipeline" wgpu-device-create-render-pipeline) wgpu-render-pipeline
  (device wgpu-device)
  (descriptor :pointer))

(defcfun ("wgpuDeviceCreateSampler" wgpu-device-create-sampler) wgpu-sampler
  (device wgpu-device)
  (descriptor :pointer))

(defcfun ("wgpuDeviceCreateShaderModule" wgpu-device-create-shader-module) wgpu-shader-module
  (device wgpu-device)
  (descriptor :pointer))

(defcfun ("wgpuDeviceCreateTexture" wgpu-device-create-texture) wgpu-texture
  (device wgpu-device)
  (descriptor :pointer))

(defcfun ("wgpuDeviceDestroy" wgpu-device-destroy) :void
  (device wgpu-device))

(defcfun ("wgpuDeviceGetFeatures" wgpu-device-get-features) :void
  (device wgpu-device)
  (features :pointer))

(defcfun ("wgpuDeviceGetLimits" wgpu-device-get-limits) wgpu-status
  (device wgpu-device)
  (limits :pointer))

;; Note: wgpuDeviceGetLostFuture returns WGPUFuture by value - use shim if needed
;; (defcfun ("wgpuDeviceGetLostFuture" wgpu-device-get-lost-future) ...)

(defcfun ("wgpuDeviceGetQueue" wgpu-device-get-queue) wgpu-queue
  (device wgpu-device))

(defcfun ("wgpuDeviceHasFeature" wgpu-device-has-feature) wgpu-bool
  (device wgpu-device)
  (feature wgpu-feature-name))

(defcfun ("wgpuDevicePushErrorScope" wgpu-device-push-error-scope) :void
  (device wgpu-device)
  (filter wgpu-error-filter))

(defcfun ("wgpuDeviceAddRef" wgpu-device-add-ref) :void
  (device wgpu-device))

(defcfun ("wgpuDeviceRelease" wgpu-device-release) :void
  (device wgpu-device))

;; ExternalTexture
(defcfun ("wgpuExternalTextureAddRef" wgpu-external-texture-add-ref) :void
  (external-texture wgpu-external-texture))

(defcfun ("wgpuExternalTextureRelease" wgpu-external-texture-release) :void
  (external-texture wgpu-external-texture))

;; Instance
(defcfun ("wgpuInstanceCreateSurface" wgpu-instance-create-surface) wgpu-surface
  (instance wgpu-instance)
  (descriptor :pointer))

(defcfun ("wgpuInstanceGetWGSLLanguageFeatures" wgpu-instance-get-wgsl-language-features) :void
  (instance wgpu-instance)
  (features :pointer))

(defcfun ("wgpuInstanceHasWGSLLanguageFeature" wgpu-instance-has-wgsl-language-feature) wgpu-bool
  (instance wgpu-instance)
  (feature wgpu-wgsl-language-feature-name))

(defcfun ("wgpuInstanceProcessEvents" wgpu-instance-process-events) :void
  (instance wgpu-instance))

(defcfun ("wgpuInstanceWaitAny" wgpu-instance-wait-any) wgpu-wait-status
  (instance wgpu-instance)
  (future-count :size)
  (futures :pointer)
  (timeout-ns :uint64))

(defcfun ("wgpuInstanceAddRef" wgpu-instance-add-ref) :void
  (instance wgpu-instance))

(defcfun ("wgpuInstanceRelease" wgpu-instance-release) :void
  (instance wgpu-instance))

;; PipelineLayout
(defcfun ("wgpuPipelineLayoutAddRef" wgpu-pipeline-layout-add-ref) :void
  (pipeline-layout wgpu-pipeline-layout))

(defcfun ("wgpuPipelineLayoutRelease" wgpu-pipeline-layout-release) :void
  (pipeline-layout wgpu-pipeline-layout))

;; QuerySet
(defcfun ("wgpuQuerySetDestroy" wgpu-query-set-destroy) :void
  (query-set wgpu-query-set))

(defcfun ("wgpuQuerySetGetCount" wgpu-query-set-get-count) :uint32
  (query-set wgpu-query-set))

(defcfun ("wgpuQuerySetGetType" wgpu-query-set-get-type) wgpu-query-type
  (query-set wgpu-query-set))

(defcfun ("wgpuQuerySetAddRef" wgpu-query-set-add-ref) :void
  (query-set wgpu-query-set))

(defcfun ("wgpuQuerySetRelease" wgpu-query-set-release) :void
  (query-set wgpu-query-set))

;; Queue
(defcfun ("wgpuQueueSubmit" wgpu-queue-submit) :void
  (queue wgpu-queue)
  (command-count :size)
  (commands :pointer))

(defcfun ("wgpuQueueWriteBuffer" wgpu-queue-write-buffer) :void
  (queue wgpu-queue)
  (buffer wgpu-buffer)
  (buffer-offset :uint64)
  (data :pointer)
  (size :size))

(defcfun ("wgpuQueueWriteTexture" wgpu-queue-write-texture) :void
  (queue wgpu-queue)
  (destination :pointer)
  (data :pointer)
  (data-size :size)
  (data-layout :pointer)
  (write-size :pointer))

(defcfun ("wgpuQueueAddRef" wgpu-queue-add-ref) :void
  (queue wgpu-queue))

(defcfun ("wgpuQueueRelease" wgpu-queue-release) :void
  (queue wgpu-queue))

;; RenderBundle
(defcfun ("wgpuRenderBundleAddRef" wgpu-render-bundle-add-ref) :void
  (render-bundle wgpu-render-bundle))

(defcfun ("wgpuRenderBundleRelease" wgpu-render-bundle-release) :void
  (render-bundle wgpu-render-bundle))

;; RenderBundleEncoder
(defcfun ("wgpuRenderBundleEncoderDraw" wgpu-render-bundle-encoder-draw) :void
  (render-bundle-encoder wgpu-render-bundle-encoder)
  (vertex-count :uint32)
  (instance-count :uint32)
  (first-vertex :uint32)
  (first-instance :uint32))

(defcfun ("wgpuRenderBundleEncoderDrawIndexed" wgpu-render-bundle-encoder-draw-indexed) :void
  (render-bundle-encoder wgpu-render-bundle-encoder)
  (index-count :uint32)
  (instance-count :uint32)
  (first-index :uint32)
  (base-vertex :int32)
  (first-instance :uint32))

(defcfun ("wgpuRenderBundleEncoderDrawIndexedIndirect" wgpu-render-bundle-encoder-draw-indexed-indirect) :void
  (render-bundle-encoder wgpu-render-bundle-encoder)
  (indirect-buffer wgpu-buffer)
  (indirect-offset :uint64))

(defcfun ("wgpuRenderBundleEncoderDrawIndirect" wgpu-render-bundle-encoder-draw-indirect) :void
  (render-bundle-encoder wgpu-render-bundle-encoder)
  (indirect-buffer wgpu-buffer)
  (indirect-offset :uint64))

(defcfun ("wgpuRenderBundleEncoderFinish" wgpu-render-bundle-encoder-finish) wgpu-render-bundle
  (render-bundle-encoder wgpu-render-bundle-encoder)
  (descriptor :pointer))

(defcfun ("wgpuRenderBundleEncoderPopDebugGroup" wgpu-render-bundle-encoder-pop-debug-group) :void
  (render-bundle-encoder wgpu-render-bundle-encoder))

(defcfun ("wgpuRenderBundleEncoderSetBindGroup" wgpu-render-bundle-encoder-set-bind-group) :void
  (render-bundle-encoder wgpu-render-bundle-encoder)
  (group-index :uint32)
  (group wgpu-bind-group)
  (dynamic-offset-count :size)
  (dynamic-offsets :pointer))

(defcfun ("wgpuRenderBundleEncoderSetIndexBuffer" wgpu-render-bundle-encoder-set-index-buffer) :void
  (render-bundle-encoder wgpu-render-bundle-encoder)
  (buffer wgpu-buffer)
  (format wgpu-index-format)
  (offset :uint64)
  (size :uint64))

(defcfun ("wgpuRenderBundleEncoderSetPipeline" wgpu-render-bundle-encoder-set-pipeline) :void
  (render-bundle-encoder wgpu-render-bundle-encoder)
  (pipeline wgpu-render-pipeline))

(defcfun ("wgpuRenderBundleEncoderSetVertexBuffer" wgpu-render-bundle-encoder-set-vertex-buffer) :void
  (render-bundle-encoder wgpu-render-bundle-encoder)
  (slot :uint32)
  (buffer wgpu-buffer)
  (offset :uint64)
  (size :uint64))

(defcfun ("wgpuRenderBundleEncoderAddRef" wgpu-render-bundle-encoder-add-ref) :void
  (render-bundle-encoder wgpu-render-bundle-encoder))

(defcfun ("wgpuRenderBundleEncoderRelease" wgpu-render-bundle-encoder-release) :void
  (render-bundle-encoder wgpu-render-bundle-encoder))

;; RenderPassEncoder
(defcfun ("wgpuRenderPassEncoderBeginOcclusionQuery" wgpu-render-pass-encoder-begin-occlusion-query) :void
  (render-pass-encoder wgpu-render-pass-encoder)
  (query-index :uint32))

(defcfun ("wgpuRenderPassEncoderDraw" wgpu-render-pass-encoder-draw) :void
  (render-pass-encoder wgpu-render-pass-encoder)
  (vertex-count :uint32)
  (instance-count :uint32)
  (first-vertex :uint32)
  (first-instance :uint32))

(defcfun ("wgpuRenderPassEncoderDrawIndexed" wgpu-render-pass-encoder-draw-indexed) :void
  (render-pass-encoder wgpu-render-pass-encoder)
  (index-count :uint32)
  (instance-count :uint32)
  (first-index :uint32)
  (base-vertex :int32)
  (first-instance :uint32))

(defcfun ("wgpuRenderPassEncoderDrawIndexedIndirect" wgpu-render-pass-encoder-draw-indexed-indirect) :void
  (render-pass-encoder wgpu-render-pass-encoder)
  (indirect-buffer wgpu-buffer)
  (indirect-offset :uint64))

(defcfun ("wgpuRenderPassEncoderDrawIndirect" wgpu-render-pass-encoder-draw-indirect) :void
  (render-pass-encoder wgpu-render-pass-encoder)
  (indirect-buffer wgpu-buffer)
  (indirect-offset :uint64))

(defcfun ("wgpuRenderPassEncoderEnd" wgpu-render-pass-encoder-end) :void
  (render-pass-encoder wgpu-render-pass-encoder))

(defcfun ("wgpuRenderPassEncoderEndOcclusionQuery" wgpu-render-pass-encoder-end-occlusion-query) :void
  (render-pass-encoder wgpu-render-pass-encoder))

(defcfun ("wgpuRenderPassEncoderExecuteBundles" wgpu-render-pass-encoder-execute-bundles) :void
  (render-pass-encoder wgpu-render-pass-encoder)
  (bundle-count :size)
  (bundles :pointer))

(defcfun ("wgpuRenderPassEncoderPopDebugGroup" wgpu-render-pass-encoder-pop-debug-group) :void
  (render-pass-encoder wgpu-render-pass-encoder))

(defcfun ("wgpuRenderPassEncoderSetBindGroup" wgpu-render-pass-encoder-set-bind-group) :void
  (render-pass-encoder wgpu-render-pass-encoder)
  (group-index :uint32)
  (group wgpu-bind-group)
  (dynamic-offset-count :size)
  (dynamic-offsets :pointer))

(defcfun ("wgpuRenderPassEncoderSetBlendConstant" wgpu-render-pass-encoder-set-blend-constant) :void
  (render-pass-encoder wgpu-render-pass-encoder)
  (color :pointer))

(defcfun ("wgpuRenderPassEncoderSetIndexBuffer" wgpu-render-pass-encoder-set-index-buffer) :void
  (render-pass-encoder wgpu-render-pass-encoder)
  (buffer wgpu-buffer)
  (format wgpu-index-format)
  (offset :uint64)
  (size :uint64))

(defcfun ("wgpuRenderPassEncoderSetPipeline" wgpu-render-pass-encoder-set-pipeline) :void
  (render-pass-encoder wgpu-render-pass-encoder)
  (pipeline wgpu-render-pipeline))

(defcfun ("wgpuRenderPassEncoderSetScissorRect" wgpu-render-pass-encoder-set-scissor-rect) :void
  (render-pass-encoder wgpu-render-pass-encoder)
  (x :uint32)
  (y :uint32)
  (width :uint32)
  (height :uint32))

(defcfun ("wgpuRenderPassEncoderSetStencilReference" wgpu-render-pass-encoder-set-stencil-reference) :void
  (render-pass-encoder wgpu-render-pass-encoder)
  (reference :uint32))

(defcfun ("wgpuRenderPassEncoderSetVertexBuffer" wgpu-render-pass-encoder-set-vertex-buffer) :void
  (render-pass-encoder wgpu-render-pass-encoder)
  (slot :uint32)
  (buffer wgpu-buffer)
  (offset :uint64)
  (size :uint64))

(defcfun ("wgpuRenderPassEncoderSetViewport" wgpu-render-pass-encoder-set-viewport) :void
  (render-pass-encoder wgpu-render-pass-encoder)
  (x :float)
  (y :float)
  (width :float)
  (height :float)
  (min-depth :float)
  (max-depth :float))

(defcfun ("wgpuRenderPassEncoderAddRef" wgpu-render-pass-encoder-add-ref) :void
  (render-pass-encoder wgpu-render-pass-encoder))

(defcfun ("wgpuRenderPassEncoderRelease" wgpu-render-pass-encoder-release) :void
  (render-pass-encoder wgpu-render-pass-encoder))

;; RenderPipeline
(defcfun ("wgpuRenderPipelineGetBindGroupLayout" wgpu-render-pipeline-get-bind-group-layout) wgpu-bind-group-layout
  (render-pipeline wgpu-render-pipeline)
  (group-index :uint32))

(defcfun ("wgpuRenderPipelineAddRef" wgpu-render-pipeline-add-ref) :void
  (render-pipeline wgpu-render-pipeline))

(defcfun ("wgpuRenderPipelineRelease" wgpu-render-pipeline-release) :void
  (render-pipeline wgpu-render-pipeline))

;; Sampler
(defcfun ("wgpuSamplerAddRef" wgpu-sampler-add-ref) :void
  (sampler wgpu-sampler))

(defcfun ("wgpuSamplerRelease" wgpu-sampler-release) :void
  (sampler wgpu-sampler))

;; ShaderModule
(defcfun ("wgpuShaderModuleAddRef" wgpu-shader-module-add-ref) :void
  (shader-module wgpu-shader-module))

(defcfun ("wgpuShaderModuleRelease" wgpu-shader-module-release) :void
  (shader-module wgpu-shader-module))

;; Surface
(defcfun ("wgpuSurfaceConfigure" wgpu-surface-configure) :void
  (surface wgpu-surface)
  (config :pointer))

(defcfun ("wgpuSurfaceGetCapabilities" wgpu-surface-get-capabilities) wgpu-status
  (surface wgpu-surface)
  (adapter wgpu-adapter)
  (capabilities :pointer))

(defcfun ("wgpuSurfaceGetCurrentTexture" wgpu-surface-get-current-texture) :void
  (surface wgpu-surface)
  (surface-texture :pointer))

(defcfun ("wgpuSurfacePresent" wgpu-surface-present) wgpu-status
  (surface wgpu-surface))

(defcfun ("wgpuSurfaceUnconfigure" wgpu-surface-unconfigure) :void
  (surface wgpu-surface))

(defcfun ("wgpuSurfaceAddRef" wgpu-surface-add-ref) :void
  (surface wgpu-surface))

(defcfun ("wgpuSurfaceRelease" wgpu-surface-release) :void
  (surface wgpu-surface))

;; Texture
(defcfun ("wgpuTextureCreateView" wgpu-texture-create-view) wgpu-texture-view
  (texture wgpu-texture)
  (descriptor :pointer))

(defcfun ("wgpuTextureDestroy" wgpu-texture-destroy) :void
  (texture wgpu-texture))

(defcfun ("wgpuTextureGetDepthOrArrayLayers" wgpu-texture-get-depth-or-array-layers) :uint32
  (texture wgpu-texture))

(defcfun ("wgpuTextureGetDimension" wgpu-texture-get-dimension) wgpu-texture-dimension
  (texture wgpu-texture))

(defcfun ("wgpuTextureGetFormat" wgpu-texture-get-format) wgpu-texture-format
  (texture wgpu-texture))

(defcfun ("wgpuTextureGetHeight" wgpu-texture-get-height) :uint32
  (texture wgpu-texture))

(defcfun ("wgpuTextureGetMipLevelCount" wgpu-texture-get-mip-level-count) :uint32
  (texture wgpu-texture))

(defcfun ("wgpuTextureGetSampleCount" wgpu-texture-get-sample-count) :uint32
  (texture wgpu-texture))

(defcfun ("wgpuTextureGetTextureBindingViewDimension" wgpu-texture-get-texture-binding-view-dimension) wgpu-texture-view-dimension
  (texture wgpu-texture))

(defcfun ("wgpuTextureGetUsage" wgpu-texture-get-usage) wgpu-flags
  (texture wgpu-texture))

(defcfun ("wgpuTextureGetWidth" wgpu-texture-get-width) :uint32
  (texture wgpu-texture))

(defcfun ("wgpuTextureAddRef" wgpu-texture-add-ref) :void
  (texture wgpu-texture))

(defcfun ("wgpuTextureRelease" wgpu-texture-release) :void
  (texture wgpu-texture))

;; TextureView
(defcfun ("wgpuTextureViewAddRef" wgpu-texture-view-add-ref) :void
  (texture-view wgpu-texture-view))

(defcfun ("wgpuTextureViewRelease" wgpu-texture-view-release) :void
  (texture-view wgpu-texture-view))

;; ============================================================================
;; wgpu.h native extension functions
;; ============================================================================

(defcfun ("wgpuGenerateReport" wgpu-generate-report) :void
  (instance wgpu-instance)
  (report :pointer))

(defcfun ("wgpuInstanceEnumerateAdapters" wgpu-instance-enumerate-adapters) :size
  (instance wgpu-instance)
  (options :pointer)
  (adapters :pointer))

(defcfun ("wgpuQueueSubmitForIndex" wgpu-queue-submit-for-index) :uint64
  (queue wgpu-queue)
  (command-count :size)
  (commands :pointer))

(defcfun ("wgpuQueueGetTimestampPeriod" wgpu-queue-get-timestamp-period) :float
  (queue wgpu-queue))

(defcfun ("wgpuDevicePoll" wgpu-device-poll) wgpu-bool
  (device wgpu-device)
  (wait wgpu-bool)
  (submission-index :pointer))

(defcfun ("wgpuDeviceCreateShaderModuleSpirV" wgpu-device-create-shader-module-spirv) wgpu-shader-module
  (device wgpu-device)
  (descriptor :pointer))

(defcfun ("wgpuSetLogLevel" wgpu-set-log-level) :void
  (level wgpu-log-level))

(defcfun ("wgpuGetVersion" wgpu-get-version) :uint32)

(defcfun ("wgpuDeviceGetNativeMetalDevice" wgpu-device-get-native-metal-device) :pointer
  (device wgpu-device))

(defcfun ("wgpuQueueGetNativeMetalCommandQueue" wgpu-queue-get-native-metal-command-queue) :pointer
  (queue wgpu-queue))

(defcfun ("wgpuTextureGetNativeMetalTexture" wgpu-texture-get-native-metal-texture) :pointer
  (texture wgpu-texture))

;; ============================================================================
;; Shim functions - these replace struct-by-value APIs with pointer versions
;; All are loaded from libwebgpu_shim
;; ============================================================================

;; FreeMembers (pointer versions)
(defcfun ("wgpu_shim_adapter_info_free_members" wgpu-shim-adapter-info-free-members) :void
  (info :pointer))

(defcfun ("wgpu_shim_supported_features_free_members" wgpu-shim-supported-features-free-members) :void
  (features :pointer))

(defcfun ("wgpu_shim_supported_instance_features_free_members" wgpu-shim-supported-instance-features-free-members) :void
  (features :pointer))

(defcfun ("wgpu_shim_supported_wgsl_language_features_free_members" wgpu-shim-supported-wgsl-language-features-free-members) :void
  (features :pointer))

(defcfun ("wgpu_shim_surface_capabilities_free_members" wgpu-shim-surface-capabilities-free-members) :void
  (capabilities :pointer))

;; GetProcAddress (string pointer version)
(defcfun ("wgpu_shim_get_proc_address" wgpu-shim-get-proc-address) :pointer
  (proc-name-data :pointer)
  (proc-name-length :size))

;; Label/DebugMarker functions (string pointer versions)
(defcfun ("wgpu_shim_bind_group_set_label" wgpu-shim-bind-group-set-label) :void
  (bind-group wgpu-bind-group)
  (data :pointer)
  (length :size))

(defcfun ("wgpu_shim_bind_group_layout_set_label" wgpu-shim-bind-group-layout-set-label) :void
  (bind-group-layout wgpu-bind-group-layout)
  (data :pointer)
  (length :size))

(defcfun ("wgpu_shim_buffer_set_label" wgpu-shim-buffer-set-label) :void
  (buffer wgpu-buffer)
  (data :pointer)
  (length :size))

(defcfun ("wgpu_shim_command_buffer_set_label" wgpu-shim-command-buffer-set-label) :void
  (command-buffer wgpu-command-buffer)
  (data :pointer)
  (length :size))

(defcfun ("wgpu_shim_command_encoder_insert_debug_marker" wgpu-shim-command-encoder-insert-debug-marker) :void
  (command-encoder wgpu-command-encoder)
  (data :pointer)
  (length :size))

(defcfun ("wgpu_shim_command_encoder_push_debug_group" wgpu-shim-command-encoder-push-debug-group) :void
  (command-encoder wgpu-command-encoder)
  (data :pointer)
  (length :size))

(defcfun ("wgpu_shim_command_encoder_set_label" wgpu-shim-command-encoder-set-label) :void
  (command-encoder wgpu-command-encoder)
  (data :pointer)
  (length :size))

(defcfun ("wgpu_shim_compute_pass_encoder_insert_debug_marker" wgpu-shim-compute-pass-encoder-insert-debug-marker) :void
  (compute-pass-encoder wgpu-compute-pass-encoder)
  (data :pointer)
  (length :size))

(defcfun ("wgpu_shim_compute_pass_encoder_push_debug_group" wgpu-shim-compute-pass-encoder-push-debug-group) :void
  (compute-pass-encoder wgpu-compute-pass-encoder)
  (data :pointer)
  (length :size))

(defcfun ("wgpu_shim_compute_pass_encoder_set_label" wgpu-shim-compute-pass-encoder-set-label) :void
  (compute-pass-encoder wgpu-compute-pass-encoder)
  (data :pointer)
  (length :size))

(defcfun ("wgpu_shim_compute_pipeline_set_label" wgpu-shim-compute-pipeline-set-label) :void
  (compute-pipeline wgpu-compute-pipeline)
  (data :pointer)
  (length :size))

(defcfun ("wgpu_shim_device_set_label" wgpu-shim-device-set-label) :void
  (device wgpu-device)
  (data :pointer)
  (length :size))

(defcfun ("wgpu_shim_external_texture_set_label" wgpu-shim-external-texture-set-label) :void
  (external-texture wgpu-external-texture)
  (data :pointer)
  (length :size))

(defcfun ("wgpu_shim_pipeline_layout_set_label" wgpu-shim-pipeline-layout-set-label) :void
  (pipeline-layout wgpu-pipeline-layout)
  (data :pointer)
  (length :size))

(defcfun ("wgpu_shim_query_set_set_label" wgpu-shim-query-set-set-label) :void
  (query-set wgpu-query-set)
  (data :pointer)
  (length :size))

(defcfun ("wgpu_shim_queue_set_label" wgpu-shim-queue-set-label) :void
  (queue wgpu-queue)
  (data :pointer)
  (length :size))

(defcfun ("wgpu_shim_render_bundle_set_label" wgpu-shim-render-bundle-set-label) :void
  (render-bundle wgpu-render-bundle)
  (data :pointer)
  (length :size))

(defcfun ("wgpu_shim_render_bundle_encoder_insert_debug_marker" wgpu-shim-render-bundle-encoder-insert-debug-marker) :void
  (render-bundle-encoder wgpu-render-bundle-encoder)
  (data :pointer)
  (length :size))

(defcfun ("wgpu_shim_render_bundle_encoder_push_debug_group" wgpu-shim-render-bundle-encoder-push-debug-group) :void
  (render-bundle-encoder wgpu-render-bundle-encoder)
  (data :pointer)
  (length :size))

(defcfun ("wgpu_shim_render_bundle_encoder_set_label" wgpu-shim-render-bundle-encoder-set-label) :void
  (render-bundle-encoder wgpu-render-bundle-encoder)
  (data :pointer)
  (length :size))

(defcfun ("wgpu_shim_render_pass_encoder_insert_debug_marker" wgpu-shim-render-pass-encoder-insert-debug-marker) :void
  (render-pass-encoder wgpu-render-pass-encoder)
  (data :pointer)
  (length :size))

(defcfun ("wgpu_shim_render_pass_encoder_push_debug_group" wgpu-shim-render-pass-encoder-push-debug-group) :void
  (render-pass-encoder wgpu-render-pass-encoder)
  (data :pointer)
  (length :size))

(defcfun ("wgpu_shim_render_pass_encoder_set_label" wgpu-shim-render-pass-encoder-set-label) :void
  (render-pass-encoder wgpu-render-pass-encoder)
  (data :pointer)
  (length :size))

(defcfun ("wgpu_shim_render_pipeline_set_label" wgpu-shim-render-pipeline-set-label) :void
  (render-pipeline wgpu-render-pipeline)
  (data :pointer)
  (length :size))

(defcfun ("wgpu_shim_sampler_set_label" wgpu-shim-sampler-set-label) :void
  (sampler wgpu-sampler)
  (data :pointer)
  (length :size))

(defcfun ("wgpu_shim_shader_module_set_label" wgpu-shim-shader-module-set-label) :void
  (shader-module wgpu-shader-module)
  (data :pointer)
  (length :size))

(defcfun ("wgpu_shim_surface_set_label" wgpu-shim-surface-set-label) :void
  (surface wgpu-surface)
  (data :pointer)
  (length :size))

(defcfun ("wgpu_shim_texture_set_label" wgpu-shim-texture-set-label) :void
  (texture wgpu-texture)
  (data :pointer)
  (length :size))

(defcfun ("wgpu_shim_texture_view_set_label" wgpu-shim-texture-view-set-label) :void
  (texture-view wgpu-texture-view)
  (data :pointer)
  (length :size))

;; ============================================================================
;; Shim async functions with decomposed callbacks
;; ============================================================================

(defcfun ("wgpu_shim_buffer_map_async" wgpu-shim-buffer-map-async) :void
  (buffer wgpu-buffer)
  (mode wgpu-flags)
  (offset :size)
  (size :size)
  (next-in-chain :pointer)
  (callback-mode wgpu-callback-mode)
  (callback :pointer)
  (userdata1 :pointer)
  (userdata2 :pointer)
  (out-future :pointer))

(defcfun ("wgpu_shim_adapter_request_device" wgpu-shim-adapter-request-device) :void
  (adapter wgpu-adapter)
  (descriptor :pointer)
  (next-in-chain :pointer)
  (callback-mode wgpu-callback-mode)
  (callback :pointer)
  (userdata1 :pointer)
  (userdata2 :pointer)
  (out-future :pointer))

(defcfun ("wgpu_shim_device_pop_error_scope" wgpu-shim-device-pop-error-scope) :void
  (device wgpu-device)
  (next-in-chain :pointer)
  (callback-mode wgpu-callback-mode)
  (callback :pointer)
  (userdata1 :pointer)
  (userdata2 :pointer)
  (out-future :pointer))

(defcfun ("wgpu_shim_queue_on_submitted_work_done" wgpu-shim-queue-on-submitted-work-done) :void
  (queue wgpu-queue)
  (next-in-chain :pointer)
  (callback-mode wgpu-callback-mode)
  (callback :pointer)
  (userdata1 :pointer)
  (userdata2 :pointer)
  (out-future :pointer))

(defcfun ("wgpu_shim_shader_module_get_compilation_info" wgpu-shim-shader-module-get-compilation-info) :void
  (shader-module wgpu-shader-module)
  (next-in-chain :pointer)
  (callback-mode wgpu-callback-mode)
  (callback :pointer)
  (userdata1 :pointer)
  (userdata2 :pointer)
  (out-future :pointer))

(defcfun ("wgpu_shim_instance_request_adapter" wgpu-shim-instance-request-adapter) :void
  (instance wgpu-instance)
  (options :pointer)
  (next-in-chain :pointer)
  (callback-mode wgpu-callback-mode)
  (callback :pointer)
  (userdata1 :pointer)
  (userdata2 :pointer)
  (out-future :pointer))

(defcfun ("wgpu_shim_device_create_compute_pipeline_async" wgpu-shim-device-create-compute-pipeline-async) :void
  (device wgpu-device)
  (descriptor :pointer)
  (next-in-chain :pointer)
  (callback-mode wgpu-callback-mode)
  (callback :pointer)
  (userdata1 :pointer)
  (userdata2 :pointer)
  (out-future :pointer))

(defcfun ("wgpu_shim_device_create_render_pipeline_async" wgpu-shim-device-create-render-pipeline-async) :void
  (device wgpu-device)
  (descriptor :pointer)
  (next-in-chain :pointer)
  (callback-mode wgpu-callback-mode)
  (callback :pointer)
  (userdata1 :pointer)
  (userdata2 :pointer)
  (out-future :pointer))

;; ============================================================================
;; Shim log callback
;; ============================================================================

(defcfun ("wgpu_shim_set_log_callback" wgpu-shim-set-log-callback) :void
  (callback :pointer)
  (userdata :pointer))

;; ============================================================================
;; Shim synchronous helpers
;; ============================================================================

(defcfun ("wgpu_shim_instance_request_adapter_sync" wgpu-shim-instance-request-adapter-sync) wgpu-request-adapter-status
  (instance wgpu-instance)
  (options :pointer)
  (out-adapter (:pointer wgpu-adapter)))

(defcfun ("wgpu_shim_adapter_request_device_sync" wgpu-shim-adapter-request-device-sync) wgpu-request-device-status
  (instance wgpu-instance)
  (adapter wgpu-adapter)
  (descriptor :pointer)
  (out-device (:pointer wgpu-device)))

;; ============================================================================
;; Silent uncaptured error callback getter
;; ============================================================================

(defcfun ("wgpu_shim_get_silent_uncaptured_error_callback" %get-silent-uncaptured-error-callback) :pointer)

;; ============================================================================
;; Export all symbols defined in this package so users can reference them easily
;; ============================================================================

(let ((pkg (find-package :cl-webgpu)))
  (do-symbols (sym pkg)
    (when (eq (symbol-package sym) pkg)
      (export sym pkg))))
