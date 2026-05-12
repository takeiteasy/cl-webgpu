/**
 * @file webgpu_shim.h
 * @brief C shim layer for Common Lisp FFI compatibility with wgpu-native.
 *
 * This header provides pointer-based and string-based alternatives to
 * wgpu-native functions that pass structs (especially WGPUStringView)
 * by value, which Common Lisp CFFI handles poorly.
 *
 * Include this header instead of webgpu.h/wgpu.h when writing FFI bindings
 * for languages that lack robust struct-by-value support.
 */

#ifndef WEBGPU_SHIM_H_
#define WEBGPU_SHIM_H_

#include <stdint.h>
#include <stddef.h>

/* We need the original headers for all type definitions */
#include "webgpu.h"
#include "wgpu.h"

#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================================
 * Callback typedefs with decomposed WGPUStringView -> (const char*, size_t)
 *
 * All WebGPU callbacks receive WGPUStringView by value. These shim types
 * split it into data+length so CFFI can handle them.
 * ============================================================================ */

typedef void (*WGPUShimBufferMapCallback)(
    WGPUMapAsyncStatus status,
    const char* message_data,
    size_t message_length,
    void* userdata1,
    void* userdata2);

typedef void (*WGPUShimCompilationInfoCallback)(
    WGPUCompilationInfoRequestStatus status,
    const struct WGPUCompilationInfo* compilationInfo,
    void* userdata1,
    void* userdata2);

typedef void (*WGPUShimCreateComputePipelineAsyncCallback)(
    WGPUCreatePipelineAsyncStatus status,
    WGPUComputePipeline pipeline,
    const char* message_data,
    size_t message_length,
    void* userdata1,
    void* userdata2);

typedef void (*WGPUShimCreateRenderPipelineAsyncCallback)(
    WGPUCreatePipelineAsyncStatus status,
    WGPURenderPipeline pipeline,
    const char* message_data,
    size_t message_length,
    void* userdata1,
    void* userdata2);

typedef void (*WGPUShimDeviceLostCallback)(
    const WGPUDevice* device,
    WGPUDeviceLostReason reason,
    const char* message_data,
    size_t message_length,
    void* userdata1,
    void* userdata2);

typedef void (*WGPUShimPopErrorScopeCallback)(
    WGPUPopErrorScopeStatus status,
    WGPUErrorType type,
    const char* message_data,
    size_t message_length,
    void* userdata1,
    void* userdata2);

typedef void (*WGPUShimQueueWorkDoneCallback)(
    WGPUQueueWorkDoneStatus status,
    const char* message_data,
    size_t message_length,
    void* userdata1,
    void* userdata2);

typedef void (*WGPUShimRequestAdapterCallback)(
    WGPURequestAdapterStatus status,
    WGPUAdapter adapter,
    const char* message_data,
    size_t message_length,
    void* userdata1,
    void* userdata2);

typedef void (*WGPUShimRequestDeviceCallback)(
    WGPURequestDeviceStatus status,
    WGPUDevice device,
    const char* message_data,
    size_t message_length,
    void* userdata1,
    void* userdata2);

typedef void (*WGPUShimUncapturedErrorCallback)(
    const WGPUDevice* device,
    WGPUErrorType type,
    const char* message_data,
    size_t message_length,
    void* userdata1,
    void* userdata2);

typedef void (*WGPUShimLogCallback)(
    WGPULogLevel level,
    const char* message_data,
    size_t message_length,
    void* userdata);

/* ============================================================================
 * WGPUStringView helpers
 * ============================================================================ */

/** Construct a WGPUStringView from C string pointer and length. */
static inline WGPUStringView wgpu_shim_make_string_view(const char* data, size_t length) {
    WGPUStringView sv;
    sv.data = data;
    sv.length = length;
    return sv;
}

/* ============================================================================
 * FreeMembers functions that took structs by value -> now take pointers
 * ============================================================================ */

void wgpu_shim_adapter_info_free_members(WGPUAdapterInfo* info);
void wgpu_shim_supported_features_free_members(WGPUSupportedFeatures* features);
void wgpu_shim_supported_instance_features_free_members(WGPUSupportedInstanceFeatures* features);
void wgpu_shim_supported_wgsl_language_features_free_members(WGPUSupportedWGSLLanguageFeatures* features);
void wgpu_shim_surface_capabilities_free_members(WGPUSurfaceCapabilities* capabilities);

/* ============================================================================
 * Label/DebugMarker/GroupLabel functions that took WGPUStringView by value
 * -> now take const char* data, size_t length
 * ============================================================================ */

WGPUProc wgpu_shim_get_proc_address(const char* proc_name_data, size_t proc_name_length);

void wgpu_shim_bind_group_set_label(WGPUBindGroup bindGroup, const char* data, size_t length);
void wgpu_shim_bind_group_layout_set_label(WGPUBindGroupLayout bindGroupLayout, const char* data, size_t length);
void wgpu_shim_buffer_set_label(WGPUBuffer buffer, const char* data, size_t length);
void wgpu_shim_command_buffer_set_label(WGPUCommandBuffer commandBuffer, const char* data, size_t length);
void wgpu_shim_command_encoder_insert_debug_marker(WGPUCommandEncoder commandEncoder, const char* data, size_t length);
void wgpu_shim_command_encoder_push_debug_group(WGPUCommandEncoder commandEncoder, const char* data, size_t length);
void wgpu_shim_command_encoder_set_label(WGPUCommandEncoder commandEncoder, const char* data, size_t length);
void wgpu_shim_compute_pass_encoder_insert_debug_marker(WGPUComputePassEncoder computePassEncoder, const char* data, size_t length);
void wgpu_shim_compute_pass_encoder_push_debug_group(WGPUComputePassEncoder computePassEncoder, const char* data, size_t length);
void wgpu_shim_compute_pass_encoder_set_label(WGPUComputePassEncoder computePassEncoder, const char* data, size_t length);
void wgpu_shim_compute_pipeline_set_label(WGPUComputePipeline computePipeline, const char* data, size_t length);
void wgpu_shim_device_set_label(WGPUDevice device, const char* data, size_t length);
void wgpu_shim_external_texture_set_label(WGPUExternalTexture externalTexture, const char* data, size_t length);
void wgpu_shim_pipeline_layout_set_label(WGPUPipelineLayout pipelineLayout, const char* data, size_t length);
void wgpu_shim_query_set_set_label(WGPUQuerySet querySet, const char* data, size_t length);
void wgpu_shim_queue_set_label(WGPUQueue queue, const char* data, size_t length);
void wgpu_shim_render_bundle_set_label(WGPURenderBundle renderBundle, const char* data, size_t length);
void wgpu_shim_render_bundle_encoder_insert_debug_marker(WGPURenderBundleEncoder renderBundleEncoder, const char* data, size_t length);
void wgpu_shim_render_bundle_encoder_push_debug_group(WGPURenderBundleEncoder renderBundleEncoder, const char* data, size_t length);
void wgpu_shim_render_bundle_encoder_set_label(WGPURenderBundleEncoder renderBundleEncoder, const char* data, size_t length);
void wgpu_shim_render_pass_encoder_insert_debug_marker(WGPURenderPassEncoder renderPassEncoder, const char* data, size_t length);
void wgpu_shim_render_pass_encoder_push_debug_group(WGPURenderPassEncoder renderPassEncoder, const char* data, size_t length);
void wgpu_shim_render_pass_encoder_set_label(WGPURenderPassEncoder renderPassEncoder, const char* data, size_t length);
void wgpu_shim_render_pipeline_set_label(WGPURenderPipeline renderPipeline, const char* data, size_t length);
void wgpu_shim_sampler_set_label(WGPUSampler sampler, const char* data, size_t length);
void wgpu_shim_shader_module_set_label(WGPUShaderModule shaderModule, const char* data, size_t length);
void wgpu_shim_surface_set_label(WGPUSurface surface, const char* data, size_t length);
void wgpu_shim_texture_set_label(WGPUTexture texture, const char* data, size_t length);
void wgpu_shim_texture_view_set_label(WGPUTextureView textureView, const char* data, size_t length);

/* ============================================================================
 * Async functions that took callback info structs by value
 * -> now take callback pointer + userdata directly
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
    WGPUFuture* out_future);

void wgpu_shim_adapter_request_device(
    WGPUAdapter adapter,
    const WGPUDeviceDescriptor* descriptor,
    WGPUChainedStruct* nextInChain,
    WGPUCallbackMode callbackMode,
    WGPUShimRequestDeviceCallback callback,
    void* userdata1,
    void* userdata2,
    WGPUFuture* out_future);

void wgpu_shim_device_pop_error_scope(
    WGPUDevice device,
    WGPUChainedStruct* nextInChain,
    WGPUCallbackMode callbackMode,
    WGPUShimPopErrorScopeCallback callback,
    void* userdata1,
    void* userdata2,
    WGPUFuture* out_future);

void wgpu_shim_queue_on_submitted_work_done(
    WGPUQueue queue,
    WGPUChainedStruct* nextInChain,
    WGPUCallbackMode callbackMode,
    WGPUShimQueueWorkDoneCallback callback,
    void* userdata1,
    void* userdata2,
    WGPUFuture* out_future);

void wgpu_shim_shader_module_get_compilation_info(
    WGPUShaderModule shaderModule,
    WGPUChainedStruct* nextInChain,
    WGPUCallbackMode callbackMode,
    WGPUShimCompilationInfoCallback callback,
    void* userdata1,
    void* userdata2,
    WGPUFuture* out_future);

/* ============================================================================
 * Log callback registration (from wgpu.h)
 * ============================================================================ */

void wgpu_shim_set_log_callback(WGPUShimLogCallback callback, void* userdata);

/* ============================================================================
 * Instance request adapter with shim callback
 * ============================================================================ */

void wgpu_shim_instance_request_adapter(
    WGPUInstance instance,
    const WGPURequestAdapterOptions* options,
    WGPUChainedStruct* nextInChain,
    WGPUCallbackMode callbackMode,
    WGPUShimRequestAdapterCallback callback,
    void* userdata1,
    void* userdata2,
    WGPUFuture* out_future);

/* ============================================================================
 * Create compute/render pipeline async with shim callbacks
 * ============================================================================ */

void wgpu_shim_device_create_compute_pipeline_async(
    WGPUDevice device,
    const WGPUComputePipelineDescriptor* descriptor,
    WGPUChainedStruct* nextInChain,
    WGPUCallbackMode callbackMode,
    WGPUShimCreateComputePipelineAsyncCallback callback,
    void* userdata1,
    void* userdata2,
    WGPUFuture* out_future);

void wgpu_shim_device_create_render_pipeline_async(
    WGPUDevice device,
    const WGPURenderPipelineDescriptor* descriptor,
    WGPUChainedStruct* nextInChain,
    WGPUCallbackMode callbackMode,
    WGPUShimCreateRenderPipelineAsyncCallback callback,
    void* userdata1,
    void* userdata2,
    WGPUFuture* out_future);

/* ============================================================================
 * Synchronous/blocking helpers for adapter/device request
 * These use wgpuInstanceWaitAny internally for convenience.
 * ============================================================================ */

/**
 * Synchronously request an adapter.
 *
 * This blocks until the adapter is received or an error occurs.
 * The returned adapter should be released with wgpuAdapterRelease.
 * If the request fails, *out_adapter is set to NULL.
 *
 * @return WGPURequestAdapterStatus status code.
 */
WGPURequestAdapterStatus wgpu_shim_instance_request_adapter_sync(
    WGPUInstance instance,
    const WGPURequestAdapterOptions* options,
    WGPUAdapter* out_adapter);

/**
 * Synchronously request a device from an adapter.
 *
 * This blocks until the device is received or an error occurs.
 * The returned device should be released with wgpuDeviceRelease.
 * If the request fails, *out_device is set to NULL.
 *
 * @param instance The WGPUInstance (needed for wgpuInstanceWaitAny).
 * @return WGPURequestDeviceStatus status code.
 */
WGPURequestDeviceStatus wgpu_shim_adapter_request_device_sync(
    WGPUInstance instance,
    WGPUAdapter adapter,
    const WGPUDeviceDescriptor* descriptor,
    WGPUDevice* out_device);

/* ============================================================================
 * Silent uncaptured error callback (prevents default panic handler)
 * ============================================================================ */

/**
 * Returns a WGPUUncapturedErrorCallback that logs errors instead of panicking.
 * This is provided because wgpu-native's DEFAULT_UNCAPTURED_ERROR_HANDLER
 * calls panic!, which crashes the host process. Use this callback in the
 * WGPUDeviceDescriptor::uncapturedErrorCallbackInfo to override the default.
 */
WGPUUncapturedErrorCallback wgpu_shim_get_silent_uncaptured_error_callback(void);


#ifdef __cplusplus
} // extern "C"
#endif

#endif // WEBGPU_SHIM_H_
