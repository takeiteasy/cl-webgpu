/**
 * @file webgpu_shim.c
 * @brief C shim implementation for Common Lisp FFI compatibility.
 */

#include "webgpu_shim.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>



/* ============================================================================
 * FreeMembers wrappers (pointer instead of by-value)
 * ============================================================================ */

void wgpu_shim_adapter_info_free_members(WGPUAdapterInfo* info) {
    if (info) {
        wgpuAdapterInfoFreeMembers(*info);
    }
}

void wgpu_shim_supported_features_free_members(WGPUSupportedFeatures* features) {
    if (features) {
        wgpuSupportedFeaturesFreeMembers(*features);
    }
}

void wgpu_shim_supported_instance_features_free_members(WGPUSupportedInstanceFeatures* features) {
    if (features) {
        wgpuSupportedInstanceFeaturesFreeMembers(*features);
    }
}

void wgpu_shim_supported_wgsl_language_features_free_members(WGPUSupportedWGSLLanguageFeatures* features) {
    if (features) {
        wgpuSupportedWGSLLanguageFeaturesFreeMembers(*features);
    }
}

void wgpu_shim_surface_capabilities_free_members(WGPUSurfaceCapabilities* capabilities) {
    if (capabilities) {
        wgpuSurfaceCapabilitiesFreeMembers(*capabilities);
    }
}

/* ============================================================================
 * WGPUStringView -> (const char*, size_t) wrappers
 * ============================================================================ */

WGPUProc wgpu_shim_get_proc_address(const char* proc_name_data, size_t proc_name_length) {
    return wgpuGetProcAddress(wgpu_shim_make_string_view(proc_name_data, proc_name_length));
}

void wgpu_shim_bind_group_set_label(WGPUBindGroup bindGroup, const char* data, size_t length) {
    wgpuBindGroupSetLabel(bindGroup, wgpu_shim_make_string_view(data, length));
}

void wgpu_shim_bind_group_layout_set_label(WGPUBindGroupLayout bindGroupLayout, const char* data, size_t length) {
    wgpuBindGroupLayoutSetLabel(bindGroupLayout, wgpu_shim_make_string_view(data, length));
}

void wgpu_shim_buffer_set_label(WGPUBuffer buffer, const char* data, size_t length) {
    wgpuBufferSetLabel(buffer, wgpu_shim_make_string_view(data, length));
}

void wgpu_shim_command_buffer_set_label(WGPUCommandBuffer commandBuffer, const char* data, size_t length) {
    wgpuCommandBufferSetLabel(commandBuffer, wgpu_shim_make_string_view(data, length));
}

void wgpu_shim_command_encoder_insert_debug_marker(WGPUCommandEncoder commandEncoder, const char* data, size_t length) {
    wgpuCommandEncoderInsertDebugMarker(commandEncoder, wgpu_shim_make_string_view(data, length));
}

void wgpu_shim_command_encoder_push_debug_group(WGPUCommandEncoder commandEncoder, const char* data, size_t length) {
    wgpuCommandEncoderPushDebugGroup(commandEncoder, wgpu_shim_make_string_view(data, length));
}

void wgpu_shim_command_encoder_set_label(WGPUCommandEncoder commandEncoder, const char* data, size_t length) {
    wgpuCommandEncoderSetLabel(commandEncoder, wgpu_shim_make_string_view(data, length));
}

void wgpu_shim_compute_pass_encoder_insert_debug_marker(WGPUComputePassEncoder computePassEncoder, const char* data, size_t length) {
    wgpuComputePassEncoderInsertDebugMarker(computePassEncoder, wgpu_shim_make_string_view(data, length));
}

void wgpu_shim_compute_pass_encoder_push_debug_group(WGPUComputePassEncoder computePassEncoder, const char* data, size_t length) {
    wgpuComputePassEncoderPushDebugGroup(computePassEncoder, wgpu_shim_make_string_view(data, length));
}

void wgpu_shim_compute_pass_encoder_set_label(WGPUComputePassEncoder computePassEncoder, const char* data, size_t length) {
    wgpuComputePassEncoderSetLabel(computePassEncoder, wgpu_shim_make_string_view(data, length));
}

void wgpu_shim_compute_pipeline_set_label(WGPUComputePipeline computePipeline, const char* data, size_t length) {
    wgpuComputePipelineSetLabel(computePipeline, wgpu_shim_make_string_view(data, length));
}

void wgpu_shim_device_set_label(WGPUDevice device, const char* data, size_t length) {
    wgpuDeviceSetLabel(device, wgpu_shim_make_string_view(data, length));
}

void wgpu_shim_external_texture_set_label(WGPUExternalTexture externalTexture, const char* data, size_t length) {
    wgpuExternalTextureSetLabel(externalTexture, wgpu_shim_make_string_view(data, length));
}

void wgpu_shim_pipeline_layout_set_label(WGPUPipelineLayout pipelineLayout, const char* data, size_t length) {
    wgpuPipelineLayoutSetLabel(pipelineLayout, wgpu_shim_make_string_view(data, length));
}

void wgpu_shim_query_set_set_label(WGPUQuerySet querySet, const char* data, size_t length) {
    wgpuQuerySetSetLabel(querySet, wgpu_shim_make_string_view(data, length));
}

void wgpu_shim_queue_set_label(WGPUQueue queue, const char* data, size_t length) {
    wgpuQueueSetLabel(queue, wgpu_shim_make_string_view(data, length));
}

void wgpu_shim_render_bundle_set_label(WGPURenderBundle renderBundle, const char* data, size_t length) {
    wgpuRenderBundleSetLabel(renderBundle, wgpu_shim_make_string_view(data, length));
}

void wgpu_shim_render_bundle_encoder_insert_debug_marker(WGPURenderBundleEncoder renderBundleEncoder, const char* data, size_t length) {
    wgpuRenderBundleEncoderInsertDebugMarker(renderBundleEncoder, wgpu_shim_make_string_view(data, length));
}

void wgpu_shim_render_bundle_encoder_push_debug_group(WGPURenderBundleEncoder renderBundleEncoder, const char* data, size_t length) {
    wgpuRenderBundleEncoderPushDebugGroup(renderBundleEncoder, wgpu_shim_make_string_view(data, length));
}

void wgpu_shim_render_bundle_encoder_set_label(WGPURenderBundleEncoder renderBundleEncoder, const char* data, size_t length) {
    wgpuRenderBundleEncoderSetLabel(renderBundleEncoder, wgpu_shim_make_string_view(data, length));
}

void wgpu_shim_render_pass_encoder_insert_debug_marker(WGPURenderPassEncoder renderPassEncoder, const char* data, size_t length) {
    wgpuRenderPassEncoderInsertDebugMarker(renderPassEncoder, wgpu_shim_make_string_view(data, length));
}

void wgpu_shim_render_pass_encoder_push_debug_group(WGPURenderPassEncoder renderPassEncoder, const char* data, size_t length) {
    wgpuRenderPassEncoderPushDebugGroup(renderPassEncoder, wgpu_shim_make_string_view(data, length));
}

void wgpu_shim_render_pass_encoder_set_label(WGPURenderPassEncoder renderPassEncoder, const char* data, size_t length) {
    wgpuRenderPassEncoderSetLabel(renderPassEncoder, wgpu_shim_make_string_view(data, length));
}

void wgpu_shim_render_pipeline_set_label(WGPURenderPipeline renderPipeline, const char* data, size_t length) {
    wgpuRenderPipelineSetLabel(renderPipeline, wgpu_shim_make_string_view(data, length));
}

void wgpu_shim_sampler_set_label(WGPUSampler sampler, const char* data, size_t length) {
    wgpuSamplerSetLabel(sampler, wgpu_shim_make_string_view(data, length));
}

void wgpu_shim_shader_module_set_label(WGPUShaderModule shaderModule, const char* data, size_t length) {
    wgpuShaderModuleSetLabel(shaderModule, wgpu_shim_make_string_view(data, length));
}

void wgpu_shim_surface_set_label(WGPUSurface surface, const char* data, size_t length) {
    wgpuSurfaceSetLabel(surface, wgpu_shim_make_string_view(data, length));
}

void wgpu_shim_texture_set_label(WGPUTexture texture, const char* data, size_t length) {
    wgpuTextureSetLabel(texture, wgpu_shim_make_string_view(data, length));
}

void wgpu_shim_texture_view_set_label(WGPUTextureView textureView, const char* data, size_t length) {
    wgpuTextureViewSetLabel(textureView, wgpu_shim_make_string_view(data, length));
}

/* ============================================================================
 * Callback trampolines
 *
 * Each WebGPU callback receives WGPUStringView by value. We need internal
 * callbacks that unpack WGPUStringView to (const char*, size_t) and forward.
 * ============================================================================ */

typedef struct {
    WGPUShimBufferMapCallback callback;
    void* userdata1;
    void* userdata2;
} WGPUShimBufferMapCallbackData;

static void wgpu_shim_buffer_map_callback_trampoline(
    WGPUMapAsyncStatus status,
    WGPUStringView message,
    void* userdata1,
    void* userdata2)
{
    (void)userdata2;
    WGPUShimBufferMapCallbackData* data = (WGPUShimBufferMapCallbackData*)userdata1;
    if (data->callback) {
        data->callback(status, message.data, message.length, data->userdata1, data->userdata2);
    }
}

typedef struct {
    WGPUShimCompilationInfoCallback callback;
    void* userdata1;
    void* userdata2;
} WGPUShimCompilationInfoCallbackData;

static void wgpu_shim_compilation_info_callback_trampoline(
    WGPUCompilationInfoRequestStatus status,
    const struct WGPUCompilationInfo* compilationInfo,
    void* userdata1,
    void* userdata2)
{
    (void)userdata2;
    WGPUShimCompilationInfoCallbackData* data = (WGPUShimCompilationInfoCallbackData*)userdata1;
    if (data->callback) {
        data->callback(status, compilationInfo, data->userdata1, data->userdata2);
    }
}

typedef struct {
    WGPUShimCreateComputePipelineAsyncCallback callback;
    void* userdata1;
    void* userdata2;
} WGPUShimCreateComputePipelineAsyncCallbackData;

static void wgpu_shim_create_compute_pipeline_async_callback_trampoline(
    WGPUCreatePipelineAsyncStatus status,
    WGPUComputePipeline pipeline,
    WGPUStringView message,
    void* userdata1,
    void* userdata2)
{
    (void)userdata2;
    WGPUShimCreateComputePipelineAsyncCallbackData* data = (WGPUShimCreateComputePipelineAsyncCallbackData*)userdata1;
    if (data->callback) {
        data->callback(status, pipeline, message.data, message.length, data->userdata1, data->userdata2);
    }
}

typedef struct {
    WGPUShimCreateRenderPipelineAsyncCallback callback;
    void* userdata1;
    void* userdata2;
} WGPUShimCreateRenderPipelineAsyncCallbackData;

static void wgpu_shim_create_render_pipeline_async_callback_trampoline(
    WGPUCreatePipelineAsyncStatus status,
    WGPURenderPipeline pipeline,
    WGPUStringView message,
    void* userdata1,
    void* userdata2)
{
    (void)userdata2;
    WGPUShimCreateRenderPipelineAsyncCallbackData* data = (WGPUShimCreateRenderPipelineAsyncCallbackData*)userdata1;
    if (data->callback) {
        data->callback(status, pipeline, message.data, message.length, data->userdata1, data->userdata2);
    }
}

typedef struct {
    WGPUShimPopErrorScopeCallback callback;
    void* userdata1;
    void* userdata2;
} WGPUShimPopErrorScopeCallbackData;

static void wgpu_shim_pop_error_scope_callback_trampoline(
    WGPUPopErrorScopeStatus status,
    WGPUErrorType type,
    WGPUStringView message,
    void* userdata1,
    void* userdata2)
{
    (void)userdata2;
    WGPUShimPopErrorScopeCallbackData* data = (WGPUShimPopErrorScopeCallbackData*)userdata1;
    if (data->callback) {
        data->callback(status, type, message.data, message.length, data->userdata1, data->userdata2);
    }
}

typedef struct {
    WGPUShimQueueWorkDoneCallback callback;
    void* userdata1;
    void* userdata2;
} WGPUShimQueueWorkDoneCallbackData;

static void wgpu_shim_queue_work_done_callback_trampoline(
    WGPUQueueWorkDoneStatus status,
    WGPUStringView message,
    void* userdata1,
    void* userdata2)
{
    (void)userdata2;
    WGPUShimQueueWorkDoneCallbackData* data = (WGPUShimQueueWorkDoneCallbackData*)userdata1;
    if (data->callback) {
        data->callback(status, message.data, message.length, data->userdata1, data->userdata2);
    }
}

typedef struct {
    WGPUShimRequestAdapterCallback callback;
    void* userdata1;
    void* userdata2;
} WGPUShimRequestAdapterCallbackData;

static void wgpu_shim_request_adapter_callback_trampoline(
    WGPURequestAdapterStatus status,
    WGPUAdapter adapter,
    WGPUStringView message,
    void* userdata1,
    void* userdata2)
{
    (void)userdata2;
    WGPUShimRequestAdapterCallbackData* data = (WGPUShimRequestAdapterCallbackData*)userdata1;
    if (data->callback) {
        data->callback(status, adapter, message.data, message.length, data->userdata1, data->userdata2);
    }
}

typedef struct {
    WGPUShimRequestDeviceCallback callback;
    void* userdata1;
    void* userdata2;
} WGPUShimRequestDeviceCallbackData;

static void wgpu_shim_request_device_callback_trampoline(
    WGPURequestDeviceStatus status,
    WGPUDevice device,
    WGPUStringView message,
    void* userdata1,
    void* userdata2)
{
    (void)userdata2;
    WGPUShimRequestDeviceCallbackData* data = (WGPUShimRequestDeviceCallbackData*)userdata1;
    if (data->callback) {
        data->callback(status, device, message.data, message.length, data->userdata1, data->userdata2);
    }
}

typedef struct {
    WGPUShimLogCallback callback;
    void* userdata;
} WGPUShimLogCallbackData;

static void wgpu_shim_log_callback_trampoline(
    WGPULogLevel level,
    WGPUStringView message,
    void* userdata)
{
    WGPUShimLogCallbackData* data = (WGPUShimLogCallbackData*)userdata;
    if (data->callback) {
        data->callback(level, message.data, message.length, data->userdata);
    }
}

/* ============================================================================
 * Async function wrappers with callback info constructed internally
 * ============================================================================ */

void wgpu_shim_buffer_map_async(
    WGPUBuffer buffer,
    WGPUMapMode mode,
    size_t offset,
    size_t size,
    WGPUChainedStruct* nextInChain,
    WGPUCallbackMode callbackMode,
    WGPUShimBufferMapCallback callback,
    void* userdata1,
    void* userdata2,
    WGPUFuture* out_future)
{
    WGPUShimBufferMapCallbackData* cb_data = (WGPUShimBufferMapCallbackData*)malloc(sizeof(WGPUShimBufferMapCallbackData));
    cb_data->callback = callback;
    cb_data->userdata1 = userdata1;
    cb_data->userdata2 = userdata2;

    WGPUBufferMapCallbackInfo info;
    info.nextInChain = nextInChain;
    info.mode = callbackMode;
    info.callback = wgpu_shim_buffer_map_callback_trampoline;
    info.userdata1 = cb_data;
    info.userdata2 = NULL;

    *out_future = wgpuBufferMapAsync(buffer, mode, offset, size, info);
}

void wgpu_shim_adapter_request_device(
    WGPUAdapter adapter,
    const WGPUDeviceDescriptor* descriptor,
    WGPUChainedStruct* nextInChain,
    WGPUCallbackMode callbackMode,
    WGPUShimRequestDeviceCallback callback,
    void* userdata1,
    void* userdata2,
    WGPUFuture* out_future)
{
    WGPUShimRequestDeviceCallbackData* cb_data = (WGPUShimRequestDeviceCallbackData*)malloc(sizeof(WGPUShimRequestDeviceCallbackData));
    cb_data->callback = callback;
    cb_data->userdata1 = userdata1;
    cb_data->userdata2 = userdata2;

    WGPURequestDeviceCallbackInfo info;
    info.nextInChain = nextInChain;
    info.mode = callbackMode;
    info.callback = wgpu_shim_request_device_callback_trampoline;
    info.userdata1 = cb_data;
    info.userdata2 = NULL;

    *out_future = wgpuAdapterRequestDevice(adapter, descriptor, info);
}

void wgpu_shim_device_pop_error_scope(
    WGPUDevice device,
    WGPUChainedStruct* nextInChain,
    WGPUCallbackMode callbackMode,
    WGPUShimPopErrorScopeCallback callback,
    void* userdata1,
    void* userdata2,
    WGPUFuture* out_future)
{
    WGPUShimPopErrorScopeCallbackData* cb_data = (WGPUShimPopErrorScopeCallbackData*)malloc(sizeof(WGPUShimPopErrorScopeCallbackData));
    cb_data->callback = callback;
    cb_data->userdata1 = userdata1;
    cb_data->userdata2 = userdata2;

    WGPUPopErrorScopeCallbackInfo info;
    info.nextInChain = nextInChain;
    info.mode = callbackMode;
    info.callback = wgpu_shim_pop_error_scope_callback_trampoline;
    info.userdata1 = cb_data;
    info.userdata2 = NULL;

    *out_future = wgpuDevicePopErrorScope(device, info);
}

void wgpu_shim_queue_on_submitted_work_done(
    WGPUQueue queue,
    WGPUChainedStruct* nextInChain,
    WGPUCallbackMode callbackMode,
    WGPUShimQueueWorkDoneCallback callback,
    void* userdata1,
    void* userdata2,
    WGPUFuture* out_future)
{
    WGPUShimQueueWorkDoneCallbackData* cb_data = (WGPUShimQueueWorkDoneCallbackData*)malloc(sizeof(WGPUShimQueueWorkDoneCallbackData));
    cb_data->callback = callback;
    cb_data->userdata1 = userdata1;
    cb_data->userdata2 = userdata2;

    WGPUQueueWorkDoneCallbackInfo info;
    info.nextInChain = nextInChain;
    info.mode = callbackMode;
    info.callback = wgpu_shim_queue_work_done_callback_trampoline;
    info.userdata1 = cb_data;
    info.userdata2 = NULL;

    *out_future = wgpuQueueOnSubmittedWorkDone(queue, info);
}

void wgpu_shim_shader_module_get_compilation_info(
    WGPUShaderModule shaderModule,
    WGPUChainedStruct* nextInChain,
    WGPUCallbackMode callbackMode,
    WGPUShimCompilationInfoCallback callback,
    void* userdata1,
    void* userdata2,
    WGPUFuture* out_future)
{
    WGPUShimCompilationInfoCallbackData* cb_data = (WGPUShimCompilationInfoCallbackData*)malloc(sizeof(WGPUShimCompilationInfoCallbackData));
    cb_data->callback = callback;
    cb_data->userdata1 = userdata1;
    cb_data->userdata2 = userdata2;

    WGPUCompilationInfoCallbackInfo info;
    info.nextInChain = nextInChain;
    info.mode = callbackMode;
    info.callback = wgpu_shim_compilation_info_callback_trampoline;
    info.userdata1 = cb_data;
    info.userdata2 = NULL;

    *out_future = wgpuShaderModuleGetCompilationInfo(shaderModule, info);
}

void wgpu_shim_instance_request_adapter(
    WGPUInstance instance,
    const WGPURequestAdapterOptions* options,
    WGPUChainedStruct* nextInChain,
    WGPUCallbackMode callbackMode,
    WGPUShimRequestAdapterCallback callback,
    void* userdata1,
    void* userdata2,
    WGPUFuture* out_future)
{
    WGPUShimRequestAdapterCallbackData* cb_data = (WGPUShimRequestAdapterCallbackData*)malloc(sizeof(WGPUShimRequestAdapterCallbackData));
    cb_data->callback = callback;
    cb_data->userdata1 = userdata1;
    cb_data->userdata2 = userdata2;

    WGPURequestAdapterCallbackInfo info;
    info.nextInChain = nextInChain;
    info.mode = callbackMode;
    info.callback = wgpu_shim_request_adapter_callback_trampoline;
    info.userdata1 = cb_data;
    info.userdata2 = NULL;

    *out_future = wgpuInstanceRequestAdapter(instance, options, info);
}

void wgpu_shim_device_create_compute_pipeline_async(
    WGPUDevice device,
    const WGPUComputePipelineDescriptor* descriptor,
    WGPUChainedStruct* nextInChain,
    WGPUCallbackMode callbackMode,
    WGPUShimCreateComputePipelineAsyncCallback callback,
    void* userdata1,
    void* userdata2,
    WGPUFuture* out_future)
{
    WGPUShimCreateComputePipelineAsyncCallbackData* cb_data = (WGPUShimCreateComputePipelineAsyncCallbackData*)malloc(sizeof(WGPUShimCreateComputePipelineAsyncCallbackData));
    cb_data->callback = callback;
    cb_data->userdata1 = userdata1;
    cb_data->userdata2 = userdata2;

    WGPUCreateComputePipelineAsyncCallbackInfo info;
    info.nextInChain = nextInChain;
    info.mode = callbackMode;
    info.callback = wgpu_shim_create_compute_pipeline_async_callback_trampoline;
    info.userdata1 = cb_data;
    info.userdata2 = NULL;

    *out_future = wgpuDeviceCreateComputePipelineAsync(device, descriptor, info);
}

void wgpu_shim_device_create_render_pipeline_async(
    WGPUDevice device,
    const WGPURenderPipelineDescriptor* descriptor,
    WGPUChainedStruct* nextInChain,
    WGPUCallbackMode callbackMode,
    WGPUShimCreateRenderPipelineAsyncCallback callback,
    void* userdata1,
    void* userdata2,
    WGPUFuture* out_future)
{
    WGPUShimCreateRenderPipelineAsyncCallbackData* cb_data = (WGPUShimCreateRenderPipelineAsyncCallbackData*)malloc(sizeof(WGPUShimCreateRenderPipelineAsyncCallbackData));
    cb_data->callback = callback;
    cb_data->userdata1 = userdata1;
    cb_data->userdata2 = userdata2;

    WGPUCreateRenderPipelineAsyncCallbackInfo info;
    info.nextInChain = nextInChain;
    info.mode = callbackMode;
    info.callback = wgpu_shim_create_render_pipeline_async_callback_trampoline;
    info.userdata1 = cb_data;
    info.userdata2 = NULL;

    *out_future = wgpuDeviceCreateRenderPipelineAsync(device, descriptor, info);
}

/* ============================================================================
 * Log callback (from wgpu.h)
 * ============================================================================ */

void wgpu_shim_set_log_callback(WGPUShimLogCallback callback, void* userdata) {
    WGPUShimLogCallbackData* cb_data = (WGPUShimLogCallbackData*)malloc(sizeof(WGPUShimLogCallbackData));
    cb_data->callback = callback;
    cb_data->userdata = userdata;
    wgpuSetLogCallback(wgpu_shim_log_callback_trampoline, cb_data);
}

/* ============================================================================
 * Synchronous/blocking helpers for adapter/device request
 * ============================================================================ */

typedef struct {
    WGPUAdapter adapter;
    WGPURequestAdapterStatus status;
    int completed;
} WGPUShimRequestAdapterSyncData;

static void wgpu_shim_request_adapter_sync_callback(
    WGPURequestAdapterStatus status,
    WGPUAdapter adapter,
    WGPUStringView message,
    void* userdata1,
    void* userdata2)
{
    (void)message;
    (void)userdata2;
    WGPUShimRequestAdapterSyncData* data = (WGPUShimRequestAdapterSyncData*)userdata1;
    data->adapter = adapter;
    data->status = status;
    data->completed = 1;
}

WGPURequestAdapterStatus wgpu_shim_instance_request_adapter_sync(
    WGPUInstance instance,
    const WGPURequestAdapterOptions* options,
    WGPUAdapter* out_adapter)
{
    WGPUShimRequestAdapterSyncData data = { NULL, WGPURequestAdapterStatus_Error, 0 };

    WGPURequestAdapterCallbackInfo info;
    info.nextInChain = NULL;
    info.mode = WGPUCallbackMode_WaitAnyOnly;
    info.callback = wgpu_shim_request_adapter_sync_callback;
    info.userdata1 = &data;
    info.userdata2 = NULL;

    /* In this version of wgpu-native, the callback is invoked synchronously
       inside wgpuInstanceRequestAdapter, so no wait is needed.
       wgpuInstanceWaitAny is unimplemented. */
    wgpuInstanceRequestAdapter(instance, options, info);

    *out_adapter = data.adapter;
    return data.status;
}

typedef struct {
    WGPUDevice device;
    WGPURequestDeviceStatus status;
    int completed;
} WGPUShimRequestDeviceSyncData;

static void wgpu_shim_request_device_sync_callback(
    WGPURequestDeviceStatus status,
    WGPUDevice device,
    WGPUStringView message,
    void* userdata1,
    void* userdata2)
{
    (void)message;
    (void)userdata2;
    WGPUShimRequestDeviceSyncData* data = (WGPUShimRequestDeviceSyncData*)userdata1;
    data->device = device;
    data->status = status;
    data->completed = 1;
}

WGPURequestDeviceStatus wgpu_shim_adapter_request_device_sync(
    WGPUInstance instance,
    WGPUAdapter adapter,
    const WGPUDeviceDescriptor* descriptor,
    WGPUDevice* out_device)
{
    WGPUShimRequestDeviceSyncData data = { NULL, WGPURequestDeviceStatus_Error, 0 };

    WGPURequestDeviceCallbackInfo info;
    info.nextInChain = NULL;
    info.mode = WGPUCallbackMode_WaitAnyOnly;
    info.callback = wgpu_shim_request_device_sync_callback;
    info.userdata1 = &data;
    info.userdata2 = NULL;

    /* In this version of wgpu-native, the callback is invoked synchronously
       inside wgpuAdapterRequestDevice, so no wait is needed.
       wgpuInstanceWaitAny is unimplemented. */
    wgpuAdapterRequestDevice(adapter, descriptor, info);

    *out_device = data.device;
    return data.status;
}

/* ============================================================================
 * Silent uncaptured error callback
 * ============================================================================ */

static void wgpu_shim_silent_uncaptured_error_callback(
    const WGPUDevice* device,
    WGPUErrorType type,
    WGPUStringView message,
    void* userdata1,
    void* userdata2)
{
    (void)device;
    (void)userdata1;
    (void)userdata2;
    fprintf(stderr, "\n=== WGPU ERROR (type=%d) ===\n%.*s\n=== END WGPU ERROR ===\n",
            (int)type, (int)message.length, message.data);
    fflush(stderr);
}

WGPUUncapturedErrorCallback wgpu_shim_get_silent_uncaptured_error_callback(void) {
    return wgpu_shim_silent_uncaptured_error_callback;
}
