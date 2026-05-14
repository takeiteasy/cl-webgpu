;;;; functions-shim.lisp
;;;; Hand-maintained CFFI bindings for the custom webgpu_shim C layer.
;;;; These replace struct-by-value APIs with pointer-based alternatives.
;;;; Do NOT regenerate this file — edit manually when shim/webgpu_shim.h changes.

(in-package #:cl-webgpu)

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
