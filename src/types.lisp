;;;; types.lisp
;;;; CFFI foreign type definitions for WebGPU

(in-package #:cl-webgpu)

;; ============================================================================
;; Opaque handle types
;; All WebGPU object handles are typedef struct WGPUXxxImpl* WGPUXxx
;; ============================================================================

(defctype wgpu-adapter :pointer)
(defctype wgpu-bind-group :pointer)
(defctype wgpu-bind-group-layout :pointer)
(defctype wgpu-buffer :pointer)
(defctype wgpu-command-buffer :pointer)
(defctype wgpu-command-encoder :pointer)
(defctype wgpu-compute-pass-encoder :pointer)
(defctype wgpu-compute-pipeline :pointer)
(defctype wgpu-device :pointer)
(defctype wgpu-external-texture :pointer)
(defctype wgpu-instance :pointer)
(defctype wgpu-pipeline-layout :pointer)
(defctype wgpu-query-set :pointer)
(defctype wgpu-queue :pointer)
(defctype wgpu-render-bundle :pointer)
(defctype wgpu-render-bundle-encoder :pointer)
(defctype wgpu-render-pass-encoder :pointer)
(defctype wgpu-render-pipeline :pointer)
(defctype wgpu-sampler :pointer)
(defctype wgpu-shader-module :pointer)
(defctype wgpu-surface :pointer)
(defctype wgpu-texture :pointer)
(defctype wgpu-texture-view :pointer)

;; Type aliases
(defctype wgpu-flags :uint64)
(defctype wgpu-bool :uint32)
(defctype wgpu-proc :pointer)

;; ============================================================================
;; WGPUStringView - used internally and in output structs
;; ============================================================================

(defcstruct (wgpu-string-view :class wgpu-string-view-c)
  (data :pointer)
  (length :size))

(defun wgpu-shim-make-string-view (data length)
  "Create a WGPUStringView-compatible foreign struct."
  (foreign-alloc '(:struct wgpu-string-view)
                 :initial-contents `((data . ,data)
                                    (length . ,length))))

;; ============================================================================
;; WGPUChainedStruct - base for extension structs
;; ============================================================================

(defcstruct (wgpu-chained-struct :class wgpu-chained-struct-c)
  (next :pointer)   ; WGPUChainedStruct*
  (s-type :uint32)) ; WGPUSType

;; ============================================================================
;; Enumerations (from webgpu.h)
;; ============================================================================

(defcenum wgpu-adapter-type
  (:discrete-gpu #x1)
  (:integrated-gpu #x2)
  (:cpu #x3)
  (:unknown #x4))

(defcenum wgpu-address-mode
  (:undefined #x0)
  (:clamp-to-edge #x1)
  (:repeat #x2)
  (:mirror-repeat #x3))

(defcenum wgpu-backend-type
  (:undefined #x0)
  (:null #x1)
  (:webgpu #x2)
  (:d3d11 #x3)
  (:d3d12 #x4)
  (:metal #x5)
  (:vulkan #x6)
  (:opengl #x7)
  (:opengles #x8))

(defcenum wgpu-blend-factor
  (:undefined #x0)
  (:zero #x1)
  (:one #x2)
  (:src #x3)
  (:one-minus-src #x4)
  (:src-alpha #x5)
  (:one-minus-src-alpha #x6)
  (:dst #x7)
  (:one-minus-dst #x8)
  (:dst-alpha #x9)
  (:one-minus-dst-alpha #xA)
  (:src-alpha-saturated #xB)
  (:constant #xC)
  (:one-minus-constant #xD)
  (:src1 #xE)
  (:one-minus-src1 #xF)
  (:src1-alpha #x10)
  (:one-minus-src1-alpha #x11))

(defcenum wgpu-blend-operation
  (:undefined #x0)
  (:add #x1)
  (:subtract #x2)
  (:reverse-subtract #x3)
  (:min #x4)
  (:max #x5))

(defcenum wgpu-buffer-binding-type
  (:binding-not-used #x0)
  (:undefined #x1)
  (:uniform #x2)
  (:storage #x3)
  (:read-only-storage #x4))

(defcenum wgpu-buffer-map-state
  (:unmapped #x1)
  (:pending #x2)
  (:mapped #x3))

(defcenum wgpu-callback-mode
  (:wait-any-only #x1)
  (:allow-process-events #x2)
  (:allow-spontaneous #x3))

(defcenum wgpu-compare-function
  (:undefined #x0)
  (:never #x1)
  (:less #x2)
  (:equal #x3)
  (:less-equal #x4)
  (:greater #x5)
  (:not-equal #x6)
  (:greater-equal #x7)
  (:always #x8))

(defcenum wgpu-compilation-info-request-status
  (:success #x1)
  (:callback-cancelled #x2))

(defcenum wgpu-compilation-message-type
  (:error #x1)
  (:warning #x2)
  (:info #x3))

(defcenum wgpu-composite-alpha-mode
  (:auto #x0)
  (:opaque #x1)
  (:premultiplied #x2)
  (:unpremultiplied #x3)
  (:inherit #x4))

(defcenum wgpu-create-pipeline-async-status
  (:success #x1)
  (:callback-cancelled #x2)
  (:validation-error #x3)
  (:internal-error #x4))

(defcenum wgpu-cull-mode
  (:undefined #x0)
  (:none #x1)
  (:front #x2)
  (:back #x3))

(defcenum wgpu-device-lost-reason
  (:unknown #x1)
  (:destroyed #x2)
  (:callback-cancelled #x3)
  (:failed-creation #x4))

(defcenum wgpu-error-filter
  (:validation #x1)
  (:out-of-memory #x2)
  (:internal #x3))

(defcenum wgpu-error-type
  (:no-error #x1)
  (:validation #x2)
  (:out-of-memory #x3)
  (:internal #x4)
  (:unknown #x5))

(defcenum wgpu-feature-level
  (:undefined #x0)
  (:compatibility #x1)
  (:core #x2))

(defcenum wgpu-feature-name
  (:core-features-and-limits #x1)
  (:depth-clip-control #x2)
  (:depth32-float-stencil8 #x3)
  (:texture-compression-bc #x4)
  (:texture-compression-bc-sliced3d #x5)
  (:texture-compression-etc2 #x6)
  (:texture-compression-astc #x7)
  (:texture-compression-astc-sliced3d #x8)
  (:timestamp-query #x9)
  (:indirect-first-instance #xA)
  (:shader-f16 #xB)
  (:rg11b10-ufloat-renderable #xC)
  (:bgra8-unorm-storage #xD)
  (:float32-filterable #xE)
  (:float32-blendable #xF)
  (:clip-distances #x10)
  (:dual-source-blending #x11)
  (:subgroups #x12)
  (:texture-formats-tier1 #x13)
  (:texture-formats-tier2 #x14)
  (:primitive-index #x15)
  (:texture-component-swizzle #x16))

(defcenum wgpu-filter-mode
  (:undefined #x0)
  (:nearest #x1)
  (:linear #x2))

(defcenum wgpu-front-face
  (:undefined #x0)
  (:ccw #x1)
  (:cw #x2))

(defcenum wgpu-index-format
  (:undefined #x0)
  (:uint16 #x1)
  (:uint32 #x2))

(defcenum wgpu-instance-feature-name
  (:timed-wait-any #x1)
  (:shader-source-spirv #x2)
  (:multiple-devices-per-adapter #x3))

(defcenum wgpu-load-op
  (:undefined #x0)
  (:load #x1)
  (:clear #x2))

(defcenum wgpu-map-async-status
  (:success #x1)
  (:callback-cancelled #x2)
  (:error #x3)
  (:aborted #x4))

(defcenum wgpu-mipmap-filter-mode
  (:undefined #x0)
  (:nearest #x1)
  (:linear #x2))

(defcenum wgpu-optional-bool
  (:false #x0)
  (:true #x1)
  (:undefined #x2))

(defcenum wgpu-pop-error-scope-status
  (:success #x1)
  (:callback-cancelled #x2)
  (:error #x3))

(defcenum wgpu-power-preference
  (:undefined #x0)
  (:low-power #x1)
  (:high-performance #x2))

(defcenum wgpu-predefined-color-space
  (:srgb #x1)
  (:display-p3 #x2))

(defcenum wgpu-present-mode
  (:undefined #x0)
  (:fifo #x1)
  (:fifo-relaxed #x2)
  (:immediate #x3)
  (:mailbox #x4))

(defcenum wgpu-primitive-topology
  (:undefined #x0)
  (:point-list #x1)
  (:line-list #x2)
  (:line-strip #x3)
  (:triangle-list #x4)
  (:triangle-strip #x5))

(defcenum wgpu-query-type
  (:occlusion #x1)
  (:timestamp #x2))

(defcenum wgpu-queue-work-done-status
  (:success #x1)
  (:callback-cancelled #x2)
  (:error #x3))

(defcenum wgpu-request-adapter-status
  (:success #x1)
  (:callback-cancelled #x2)
  (:unavailable #x3)
  (:error #x4))

(defcenum wgpu-request-device-status
  (:success #x1)
  (:callback-cancelled #x2)
  (:error #x3))

(defcenum wgpu-s-type
  (:shader-source-spirv #x1)
  (:shader-source-wgsl #x2)
  (:render-pass-max-draw-count #x3)
  (:surface-source-metal-layer #x4)
  (:surface-source-windows-hwnd #x5)
  (:surface-source-xlib-window #x6)
  (:surface-source-wayland-surface #x7)
  (:surface-source-android-native-window #x8)
  (:surface-source-xcb-window #x9)
  (:surface-color-management #xA)
  (:request-adapter-webxr-options #xB)
  (:texture-component-swizzle-descriptor #xC)
  (:external-texture-binding-layout #xD)
  (:external-texture-binding-entry #xE)
  (:compatibility-mode-limits #xF)
  (:texture-binding-view-dimension #x10))

(defcenum wgpu-sampler-binding-type
  (:binding-not-used #x0)
  (:undefined #x1)
  (:filtering #x2)
  (:non-filtering #x3)
  (:comparison #x4))

(defcenum wgpu-status
  (:success #x1)
  (:error #x2))

(defcenum wgpu-stencil-operation
  (:undefined #x0)
  (:keep #x1)
  (:zero #x2)
  (:replace #x3)
  (:invert #x4)
  (:increment-clamp #x5)
  (:decrement-clamp #x6)
  (:increment-wrap #x7)
  (:decrement-wrap #x8))

(defcenum wgpu-storage-texture-access
  (:binding-not-used #x0)
  (:undefined #x1)
  (:write-only #x2)
  (:read-only #x3)
  (:read-write #x4))

(defcenum wgpu-store-op
  (:undefined #x0)
  (:store #x1)
  (:discard #x2))

(defcenum wgpu-surface-get-current-texture-status
  (:success-optimal #x1)
  (:success-suboptimal #x2)
  (:timeout #x3)
  (:outdated #x4)
  (:lost #x5)
  (:error #x6))

(defcenum wgpu-texture-aspect
  (:undefined #x0)
  (:all #x1)
  (:stencil-only #x2)
  (:depth-only #x3))

(defcenum wgpu-texture-dimension
  (:undefined #x0)
  (:1d #x1)
  (:2d #x2)
  (:3d #x3))

(defcenum wgpu-texture-format
  (:undefined #x0)
  (:r8-unorm #x1)
  (:r8-snorm #x2)
  (:r8-uint #x3)
  (:r8-sint #x4)
  (:r16-unorm #x5)
  (:r16-snorm #x6)
  (:r16-uint #x7)
  (:r16-sint #x8)
  (:r16-float #x9)
  (:rg8-unorm #xA)
  (:rg8-snorm #xB)
  (:rg8-uint #xC)
  (:rg8-sint #xD)
  (:r32-float #xE)
  (:r32-uint #xF)
  (:r32-sint #x10)
  (:rg16-uint #x11)
  (:rg16-sint #x12)
  (:rg16-float #x13)
  (:rgba8-unorm #x16)
  (:rgba8-unorm-srgb #x17)
  (:rgba8-snorm #x18)
  (:rgba8-uint #x19)
  (:rgba8-sint #x1A)
  (:bgra8-unorm #x1B)
  (:bgra8-unorm-srgb #x1C)
  (:rgb10a2-uint #x1D)
  (:rgb10a2-unorm #x1E)
  (:rg11b10-ufloat #x1F)
  (:rgb9e5-ufloat #x20)
  (:rg32-float #x21)
  (:rg32-uint #x22)
  (:rg32-sint #x23)
  (:rgba16-uint #x24)
  (:rgba16-sint #x25)
  (:rgba16-float #x26)
  (:rgba32-float #x29)
  (:rgba32-uint #x2A)
  (:rgba32-sint #x2B)
  (:stencil8 #x2C)
  (:depth16-unorm #x2D)
  (:depth24-plus #x2E)
  (:depth24-plus-stencil8 #x2F)
  (:depth32-float #x30)
  (:depth32-float-stencil8 #x31)
  (:bc1rgba-unorm #x32)
  (:bc1rgba-unorm-srgb #x33)
  (:bc2rgba-unorm #x34)
  (:bc2rgba-unorm-srgb #x35)
  (:bc3rgba-unorm #x36)
  (:bc3rgba-unorm-srgb #x37)
  (:bc4r-unorm #x38)
  (:bc4r-snorm #x39)
  (:bc5rg-unorm #x3A)
  (:bc5rg-snorm #x3B)
  (:bc6h-rgb-ufloat #x3C)
  (:bc6h-rgb-float #x3D)
  (:bc7rgba-unorm #x3E)
  (:bc7rgba-unorm-srgb #x3F)
  (:etc2-rgb8-unorm #x40)
  (:etc2-rgb8-unorm-srgb #x41)
  (:etc2-rgb8a1-unorm #x42)
  (:etc2-rgb8a1-unorm-srgb #x43)
  (:etc2-rgba8-unorm #x44)
  (:etc2-rgba8-unorm-srgb #x45)
  (:eac-r11-unorm #x46)
  (:eac-r11-snorm #x47)
  (:eac-rg11-unorm #x48)
  (:eac-rg11-snorm #x49)
  (:astc-4x4-unorm #x4A)
  (:astc-4x4-unorm-srgb #x4B)
  (:astc-5x4-unorm #x4C)
  (:astc-5x4-unorm-srgb #x4D)
  (:astc-5x5-unorm #x4E)
  (:astc-5x5-unorm-srgb #x4F)
  (:astc-6x5-unorm #x50)
  (:astc-6x5-unorm-srgb #x51)
  (:astc-6x6-unorm #x52)
  (:astc-6x6-unorm-srgb #x53)
  (:astc-8x5-unorm #x54)
  (:astc-8x5-unorm-srgb #x55)
  (:astc-8x6-unorm #x56)
  (:astc-8x6-unorm-srgb #x57)
  (:astc-8x8-unorm #x58)
  (:astc-8x8-unorm-srgb #x59)
  (:astc-10x5-unorm #x5A)
  (:astc-10x5-unorm-srgb #x5B)
  (:astc-10x6-unorm #x5C)
  (:astc-10x6-unorm-srgb #x5D)
  (:astc-10x8-unorm #x5E)
  (:astc-10x8-unorm-srgb #x5F)
  (:astc-10x10-unorm #x60)
  (:astc-10x10-unorm-srgb #x61)
  (:astc-12x10-unorm #x62)
  (:astc-12x10-unorm-srgb #x63)
  (:astc-12x12-unorm #x64)
  (:astc-12x12-unorm-srgb #x65))

(defcenum wgpu-texture-sample-type
  (:binding-not-used #x0)
  (:undefined #x1)
  (:float #x2)
  (:unfilterable-float #x3)
  (:depth #x4)
  (:sint #x5)
  (:uint #x6))

(defcenum wgpu-texture-view-dimension
  (:undefined #x0)
  (:1d #x1)
  (:2d #x2)
  (:2d-array #x3)
  (:cube #x4)
  (:cube-array #x5)
  (:3d #x6))

(defcenum wgpu-tone-mapping-mode
  (:standard #x1)
  (:extended #x2))

(defcenum wgpu-vertex-format
  (:uint8 #x1)
  (:uint8x2 #x2)
  (:uint8x4 #x3)
  (:sint8 #x4)
  (:sint8x2 #x5)
  (:sint8x4 #x6)
  (:unorm8 #x7)
  (:unorm8x2 #x8)
  (:unorm8x4 #x9)
  (:snorm8 #xA)
  (:snorm8x2 #xB)
  (:snorm8x4 #xC)
  (:uint16 #xD)
  (:uint16x2 #xE)
  (:uint16x4 #xF)
  (:sint16 #x10)
  (:sint16x2 #x11)
  (:sint16x4 #x12)
  (:unorm16 #x13)
  (:unorm16x2 #x14)
  (:unorm16x4 #x15)
  (:snorm16 #x16)
  (:snorm16x2 #x17)
  (:snorm16x4 #x18)
  (:float16 #x19)
  (:float16x2 #x1A)
  (:float16x4 #x1B)
  (:float32 #x1C)
  (:float32x2 #x1D)
  (:float32x3 #x1E)
  (:float32x4 #x1F)
  (:uint32 #x20)
  (:uint32x2 #x21)
  (:uint32x3 #x22)
  (:uint32x4 #x23)
  (:sint32 #x24)
  (:sint32x2 #x25)
  (:sint32x3 #x26)
  (:sint32x4 #x27)
  (:unorm10-10-10-2 #x28)
  (:unorm8x4-bgra #x29))

(defcenum wgpu-vertex-step-mode
  (:undefined #x0)
  (:vertex #x1)
  (:instance #x2))

(defcenum wgpu-wgsl-language-feature-name
  (:readonly-and-readwrite-storage-textures #x1)
  (:packed4x8-integer-dot-product #x2)
  (:unrestricted-pointer-parameters #x3)
  (:pointer-composite-access #x4)
  (:uniform-buffer-standard-layout #x5)
  (:subgroup-id #x6)
  (:texture-and-sampler-let #x7)
  (:subgroup-uniformity #x8)
  (:texture-formats-tier1 #x9)
  (:linear-indexing #xA))

(defcenum wgpu-wait-status
  (:success #x1)
  (:timed-out #x2)
  (:error #x3))

;; ============================================================================
;; Bitflag constants
;; ============================================================================

(defconstant +wgpu-buffer-usage-none+ 0)
(defconstant +wgpu-buffer-usage-map-read+ #x1)
(defconstant +wgpu-buffer-usage-map-write+ #x2)
(defconstant +wgpu-buffer-usage-copy-src+ #x4)
(defconstant +wgpu-buffer-usage-copy-dst+ #x8)
(defconstant +wgpu-buffer-usage-index+ #x10)
(defconstant +wgpu-buffer-usage-vertex+ #x20)
(defconstant +wgpu-buffer-usage-uniform+ #x40)
(defconstant +wgpu-buffer-usage-storage+ #x80)
(defconstant +wgpu-buffer-usage-indirect+ #x100)
(defconstant +wgpu-buffer-usage-query-resolve+ #x200)

(defconstant +wgpu-color-write-mask-none+ 0)
(defconstant +wgpu-color-write-mask-red+ #x1)
(defconstant +wgpu-color-write-mask-green+ #x2)
(defconstant +wgpu-color-write-mask-blue+ #x4)
(defconstant +wgpu-color-write-mask-alpha+ #x8)
(defconstant +wgpu-color-write-mask-all+ #xF)

(defconstant +wgpu-map-mode-none+ 0)
(defconstant +wgpu-map-mode-read+ #x1)
(defconstant +wgpu-map-mode-write+ #x2)

(defconstant +wgpu-shader-stage-none+ 0)
(defconstant +wgpu-shader-stage-vertex+ #x1)
(defconstant +wgpu-shader-stage-fragment+ #x2)
(defconstant +wgpu-shader-stage-compute+ #x4)

(defconstant +wgpu-texture-usage-none+ 0)
(defconstant +wgpu-texture-usage-copy-src+ #x1)
(defconstant +wgpu-texture-usage-copy-dst+ #x2)
(defconstant +wgpu-texture-usage-texture-binding+ #x4)
(defconstant +wgpu-texture-usage-storage-binding+ #x8)
(defconstant +wgpu-texture-usage-render-attachment+ #x10)

;; ============================================================================
;; Core structs (passed by pointer)
;; ============================================================================

(defcstruct wgpu-color
  (r :double)
  (g :double)
  (b :double)
  (a :double))

(defcstruct wgpu-extent-3d
  (width :uint32)
  (height :uint32)
  (depth-or-array-layers :uint32))

(defcstruct wgpu-origin-3d
  (x :uint32)
  (y :uint32)
  (z :uint32))

(defcstruct wgpu-blend-component
  (operation wgpu-blend-operation)
  (src-factor wgpu-blend-factor)
  (dst-factor wgpu-blend-factor))

(defcstruct wgpu-blend-state
  (color (:struct wgpu-blend-component))
  (alpha (:struct wgpu-blend-component)))

(defcstruct wgpu-stencil-face-state
  (compare wgpu-compare-function)
  (fail-op wgpu-stencil-operation)
  (depth-fail-op wgpu-stencil-operation)
  (pass-op wgpu-stencil-operation))

(defcstruct wgpu-buffer-binding-layout
  (next-in-chain :pointer)
  (type wgpu-buffer-binding-type)
  (has-dynamic-offset wgpu-bool)
  (min-binding-size :uint64))

(defcstruct wgpu-sampler-binding-layout
  (next-in-chain :pointer)
  (type wgpu-sampler-binding-type))

(defcstruct wgpu-texture-binding-layout
  (next-in-chain :pointer)
  (sample-type wgpu-texture-sample-type)
  (view-dimension wgpu-texture-view-dimension)
  (multisampled wgpu-bool))

(defcstruct wgpu-storage-texture-binding-layout
  (next-in-chain :pointer)
  (access wgpu-storage-texture-access)
  (format wgpu-texture-format)
  (view-dimension wgpu-texture-view-dimension))

(defcstruct wgpu-bind-group-layout-entry
  (next-in-chain :pointer)
  (binding :uint32)
  (visibility wgpu-flags)
  (buffer (:struct wgpu-buffer-binding-layout))
  (sampler (:struct wgpu-sampler-binding-layout))
  (texture (:struct wgpu-texture-binding-layout))
  (storage-texture (:struct wgpu-storage-texture-binding-layout)))

(defcstruct wgpu-bind-group-entry
  (next-in-chain :pointer)
  (binding :uint32)
  (buffer wgpu-buffer)
  (offset :uint64)
  (size :uint64)
  (sampler wgpu-sampler)
  (texture-view wgpu-texture-view))

(defcstruct wgpu-vertex-attribute
  (format wgpu-vertex-format)
  (offset :uint64)
  (shader-location :uint32))

(defcstruct wgpu-vertex-buffer-layout
  (step-mode wgpu-vertex-step-mode)
  (array-stride :uint64)
  (attribute-count :size)
  (attributes :pointer))

(defcstruct wgpu-color-target-state
  (next-in-chain :pointer)
  (format wgpu-texture-format)
  (blend :pointer)  ; const WGPUBlendState* (nullable)
  (write-mask wgpu-flags))

(defcstruct wgpu-constant-entry
  (next-in-chain :pointer)
  (key (:struct wgpu-string-view))
  (value :double))

(defcstruct wgpu-programmable-stage-descriptor
  (next-in-chain :pointer)
  (module wgpu-shader-module)
  (entry-point (:struct wgpu-string-view))
  (constant-count :size)
  (constants :pointer))

(defcstruct wgpu-vertex-state
  (next-in-chain :pointer)
  (module wgpu-shader-module)
  (entry-point (:struct wgpu-string-view))
  (constant-count :size)
  (constants :pointer)
  (buffer-count :size)
  (buffers :pointer))

(defcstruct wgpu-fragment-state
  (next-in-chain :pointer)
  (module wgpu-shader-module)
  (entry-point (:struct wgpu-string-view))
  (constant-count :size)
  (constants :pointer)
  (target-count :size)
  (targets :pointer))

(defcstruct wgpu-primitive-state
  (next-in-chain :pointer)
  (topology wgpu-primitive-topology)
  (strip-index-format wgpu-index-format)
  (front-face wgpu-front-face)
  (cull-mode wgpu-cull-mode)
  (unclipped-depth wgpu-bool))

(defcstruct wgpu-multisample-state
  (next-in-chain :pointer)
  (count :uint32)
  (mask :uint32)
  (alpha-to-coverage-enabled wgpu-bool))

(defcstruct wgpu-depth-stencil-state
  (next-in-chain :pointer)
  (format wgpu-texture-format)
  (depth-write-enabled wgpu-optional-bool)
  (depth-compare wgpu-compare-function)
  (stencil-front (:struct wgpu-stencil-face-state))
  (stencil-back (:struct wgpu-stencil-face-state))
  (stencil-read-mask :uint32)
  (stencil-write-mask :uint32)
  (depth-bias :int32)
  (depth-bias-slope-scale :float)
  (depth-bias-clamp :float))

(defcstruct wgpu-render-pass-color-attachment
  (next-in-chain :pointer)
  (view wgpu-texture-view)
  (depth-slice :uint32)
  (resolve-target wgpu-texture-view)
  (load-op wgpu-load-op)
  (store-op wgpu-store-op)
  (clear-value (:struct wgpu-color)))

(defcstruct wgpu-render-pass-depth-stencil-attachment
  (view wgpu-texture-view)
  (depth-load-op wgpu-load-op)
  (depth-store-op wgpu-store-op)
  (depth-clear-value :float)
  (depth-read-only wgpu-bool)
  (stencil-load-op wgpu-load-op)
  (stencil-store-op wgpu-store-op)
  (stencil-clear-value :uint32)
  (stencil-read-only wgpu-bool))

(defcstruct wgpu-render-pass-timestamp-writes
  (query-set wgpu-query-set)
  (beginning-of-pass-write-index :uint32)
  (end-of-pass-write-index :uint32))

(defcstruct wgpu-compute-pass-timestamp-writes
  (query-set wgpu-query-set)
  (beginning-of-pass-write-index :uint32)
  (end-of-pass-write-index :uint32))

(defcstruct wgpu-buffer-descriptor
  (next-in-chain :pointer)
  (label (:struct wgpu-string-view))
  (usage wgpu-flags)
  (size :uint64)
  (mapped-at-creation wgpu-bool))

(defcstruct wgpu-texture-descriptor
  (next-in-chain :pointer)
  (label (:struct wgpu-string-view))
  (usage wgpu-flags)
  (dimension wgpu-texture-dimension)
  (size (:struct wgpu-extent-3d))
  (format wgpu-texture-format)
  (mip-level-count :uint32)
  (sample-count :uint32)
  (view-format-count :size)
  (view-formats :pointer))

(defcstruct wgpu-texture-view-descriptor
  (next-in-chain :pointer)
  (label (:struct wgpu-string-view))
  (format wgpu-texture-format)
  (dimension wgpu-texture-view-dimension)
  (base-mip-level :uint32)
  (mip-level-count :uint32)
  (base-array-layer :uint32)
  (array-layer-count :uint32)
  (aspect wgpu-texture-aspect)
  (usage wgpu-flags))

(defcstruct wgpu-sampler-descriptor
  (next-in-chain :pointer)
  (label (:struct wgpu-string-view))
  (address-mode-u wgpu-address-mode)
  (address-mode-v wgpu-address-mode)
  (address-mode-w wgpu-address-mode)
  (mag-filter wgpu-filter-mode)
  (min-filter wgpu-filter-mode)
  (mipmap-filter wgpu-mipmap-filter-mode)
  (lod-min-clamp :float)
  (lod-max-clamp :float)
  (compare wgpu-compare-function)
  (max-anisotropy :uint16))

(defcstruct wgpu-query-set-descriptor
  (next-in-chain :pointer)
  (label (:struct wgpu-string-view))
  (type wgpu-query-type)
  (count :uint32))

(defcstruct wgpu-command-buffer-descriptor
  (next-in-chain :pointer)
  (label (:struct wgpu-string-view)))

(defcstruct wgpu-queue-descriptor
  (next-in-chain :pointer)
  (label (:struct wgpu-string-view)))

(defcstruct wgpu-device-lost-callback-info
  (next-in-chain :pointer)
  (mode wgpu-callback-mode)
  (callback :pointer)
  (userdata1 :pointer)
  (userdata2 :pointer))

(defcstruct wgpu-uncaptured-error-callback-info
  (next-in-chain :pointer)
  (callback :pointer)
  (userdata1 :pointer)
  (userdata2 :pointer))

(defcstruct wgpu-command-encoder-descriptor
  (next-in-chain :pointer)
  (label (:struct wgpu-string-view)))

(defcstruct wgpu-render-bundle-descriptor
  (next-in-chain :pointer)
  (label (:struct wgpu-string-view)))

(defcstruct wgpu-render-bundle-encoder-descriptor
  (next-in-chain :pointer)
  (label (:struct wgpu-string-view))
  (color-format-count :size)
  (color-formats :pointer)
  (depth-stencil-format wgpu-texture-format)
  (sample-count :uint32)
  (depth-read-only wgpu-bool)
  (stencil-read-only wgpu-bool))

(defcstruct wgpu-compute-pass-descriptor
  (next-in-chain :pointer)
  (label (:struct wgpu-string-view))
  (timestamp-writes :pointer))

(defcstruct wgpu-render-pass-descriptor
  (next-in-chain :pointer)
  (label (:struct wgpu-string-view))
  (color-attachment-count :size)
  (color-attachments :pointer)
  (depth-stencil-attachment :pointer)
  (occlusion-query-set wgpu-query-set)
  (timestamp-writes :pointer))

(defcstruct wgpu-bind-group-descriptor
  (next-in-chain :pointer)
  (label (:struct wgpu-string-view))
  (layout wgpu-bind-group-layout)
  (entry-count :size)
  (entries :pointer))

(defcstruct wgpu-bind-group-layout-descriptor
  (next-in-chain :pointer)
  (label (:struct wgpu-string-view))
  (entry-count :size)
  (entries :pointer))

(defcstruct wgpu-pipeline-layout-descriptor
  (next-in-chain :pointer)
  (label (:struct wgpu-string-view))
  (bind-group-layout-count :size)
  (bind-group-layouts :pointer))

(defcstruct wgpu-shader-module-descriptor
  (next-in-chain :pointer)
  (label (:struct wgpu-string-view)))

(defcstruct wgpu-shader-source-wgsl
  (chain (:struct wgpu-chained-struct))
  (code (:struct wgpu-string-view)))

(defcstruct wgpu-shader-source-spirv
  (chain (:struct wgpu-chained-struct))
  (code-size :uint32)
  (code :pointer))

(defcstruct wgpu-compute-pipeline-descriptor
  (next-in-chain :pointer)
  (label (:struct wgpu-string-view))
  (layout wgpu-pipeline-layout)
  (compute (:struct wgpu-programmable-stage-descriptor)))

(defcstruct wgpu-render-pipeline-descriptor
  (next-in-chain :pointer)
  (label (:struct wgpu-string-view))
  (layout wgpu-pipeline-layout)
  (vertex (:struct wgpu-vertex-state))
  (primitive (:struct wgpu-primitive-state))
  (depth-stencil :pointer)
  (multisample (:struct wgpu-multisample-state))
  (fragment :pointer))

(defcstruct wgpu-limits
  (next-in-chain :pointer)
  (max-texture-dimension-1d :uint32)
  (max-texture-dimension-2d :uint32)
  (max-texture-dimension-3d :uint32)
  (max-texture-array-layers :uint32)
  (max-bind-groups :uint32)
  (max-bind-groups-plus-vertex-buffers :uint32)
  (max-bindings-per-bind-group :uint32)
  (max-dynamic-uniform-buffers-per-pipeline-layout :uint32)
  (max-dynamic-storage-buffers-per-pipeline-layout :uint32)
  (max-sampled-textures-per-shader-stage :uint32)
  (max-samplers-per-shader-stage :uint32)
  (max-storage-buffers-per-shader-stage :uint32)
  (max-storage-textures-per-shader-stage :uint32)
  (max-uniform-buffers-per-shader-stage :uint32)
  (max-uniform-buffer-binding-size :uint64)
  (max-storage-buffer-binding-size :uint64)
  (min-uniform-buffer-offset-alignment :uint32)
  (min-storage-buffer-offset-alignment :uint32)
  (max-vertex-buffers :uint32)
  (max-buffer-size :uint64)
  (max-vertex-attributes :uint32)
  (max-vertex-buffer-array-stride :uint32)
  (max-inter-stage-shader-variables :uint32)
  (max-color-attachments :uint32)
  (max-color-attachment-bytes-per-sample :uint32)
  (max-compute-workgroup-storage-size :uint32)
  (max-compute-invocations-per-workgroup :uint32)
  (max-compute-workgroup-size-x :uint32)
  (max-compute-workgroup-size-y :uint32)
  (max-compute-workgroup-size-z :uint32)
  (max-compute-workgroups-per-dimension :uint32))

(defcstruct wgpu-adapter-info
  (next-in-chain :pointer)
  (vendor (:struct wgpu-string-view))
  (architecture (:struct wgpu-string-view))
  (device (:struct wgpu-string-view))
  (description (:struct wgpu-string-view))
  (backend-type wgpu-backend-type)
  (adapter-type wgpu-adapter-type)
  (vendor-id :uint32)
  (device-id :uint32))

(defcstruct wgpu-supported-features
  (feature-count :size)
  (features :pointer))

(defcstruct wgpu-supported-instance-features
  (feature-count :size)
  (features :pointer))

(defcstruct wgpu-supported-wgsl-language-features
  (feature-count :size)
  (features :pointer))

(defcstruct wgpu-request-adapter-options
  (next-in-chain :pointer)
  (feature-level wgpu-feature-level)
  (power-preference wgpu-power-preference)
  (force-fallback-adapter wgpu-bool)
  (backend-type wgpu-backend-type)
  (compatible-surface wgpu-surface))

(defcstruct wgpu-device-descriptor
  (next-in-chain :pointer)
  (label (:struct wgpu-string-view))
  (required-feature-count :size)
  (required-features :pointer)
  (required-limits :pointer)
  (default-queue (:struct wgpu-queue-descriptor))
  (device-lost-callback-info (:struct wgpu-device-lost-callback-info))
  (uncaptured-error-callback-info (:struct wgpu-uncaptured-error-callback-info)))

(defcstruct wgpu-instance-descriptor
  (next-in-chain :pointer)
  (features (:struct wgpu-supported-instance-features)))

(defcstruct wgpu-instance-capabilities
  (next-in-chain :pointer)
  (timed-wait-any-enable wgpu-bool)
  (timed-wait-any-max-count :size))

(defcstruct wgpu-instance-limits
  (next-in-chain :pointer)
  (max-texture-dimension-1d :uint32)
  (max-texture-dimension-2d :uint32)
  (max-texture-dimension-3d :uint32)
  (max-texture-array-layers :uint32)
  (max-bind-groups :uint32)
  (max-bind-groups-plus-vertex-buffers :uint32)
  (max-bindings-per-bind-group :uint32)
  (max-dynamic-uniform-buffers-per-pipeline-layout :uint32)
  (max-dynamic-storage-buffers-per-pipeline-layout :uint32)
  (max-sampled-textures-per-shader-stage :uint32)
  (max-samplers-per-shader-stage :uint32)
  (max-storage-buffers-per-shader-stage :uint32)
  (max-storage-textures-per-shader-stage :uint32)
  (max-uniform-buffers-per-shader-stage :uint32)
  (max-uniform-buffer-binding-size :uint64)
  (max-storage-buffer-binding-size :uint64)
  (min-uniform-buffer-offset-alignment :uint32)
  (min-storage-buffer-offset-alignment :uint32)
  (max-vertex-buffers :uint32)
  (max-buffer-size :uint64)
  (max-vertex-attributes :uint32)
  (max-vertex-buffer-array-stride :uint32)
  (max-inter-stage-shader-variables :uint32)
  (max-color-attachments :uint32)
  (max-color-attachment-bytes-per-sample :uint32)
  (max-compute-workgroup-storage-size :uint32)
  (max-compute-invocations-per-workgroup :uint32)
  (max-compute-workgroup-size-x :uint32)
  (max-compute-workgroup-size-y :uint32)
  (max-compute-workgroup-size-z :uint32)
  (max-compute-workgroups-per-dimension :uint32))

(defcstruct wgpu-instance-enumerate-adapter-options
  (next-in-chain :pointer)
  (backends wgpu-flags))

(defcstruct wgpu-surface-descriptor
  (next-in-chain :pointer)
  (label (:struct wgpu-string-view)))

(defcstruct wgpu-surface-source-metal-layer
  (chain (:struct wgpu-chained-struct))
  (layer :pointer))

(defcstruct wgpu-surface-source-windows-hwnd
  (chain (:struct wgpu-chained-struct))
  (hinstance :pointer)
  (hwnd :pointer))

(defcstruct wgpu-surface-source-xlib-window
  (chain (:struct wgpu-chained-struct))
  (display :pointer)
  (window :uint64))

(defcstruct wgpu-surface-source-xcb-window
  (chain (:struct wgpu-chained-struct))
  (connection :pointer)
  (window :uint32))

(defcstruct wgpu-surface-source-wayland-surface
  (chain (:struct wgpu-chained-struct))
  (display :pointer)
  (surface :pointer))

(defcstruct wgpu-surface-source-android-native-window
  (chain (:struct wgpu-chained-struct))
  (window :pointer))

(defcstruct wgpu-surface-configuration
  (next-in-chain :pointer)
  (device wgpu-device)
  (format wgpu-texture-format)
  (usage wgpu-flags)
  (width :uint32)
  (height :uint32)
  (view-format-count :size)
  (view-formats :pointer)
  (alpha-mode wgpu-composite-alpha-mode)
  (present-mode wgpu-present-mode))

(defcstruct wgpu-surface-capabilities
  (next-in-chain :pointer)
  (usages wgpu-flags)
  (format-count :size)
  (formats :pointer)
  (present-mode-count :size)
  (present-modes :pointer)
  (alpha-mode-count :size)
  (alpha-modes :pointer))

(defcstruct wgpu-surface-texture
  (next-in-chain :pointer)
  (texture wgpu-texture)
  (status wgpu-surface-get-current-texture-status))

(defcstruct wgpu-texel-copy-buffer-layout
  (offset :uint64)
  (bytes-per-row :uint32)
  (rows-per-image :uint32))

(defcstruct wgpu-texel-copy-buffer-info
  (layout (:struct wgpu-texel-copy-buffer-layout))
  (buffer wgpu-buffer))

(defcstruct wgpu-texel-copy-texture-info
  (texture wgpu-texture)
  (mip-level :uint32)
  (origin (:struct wgpu-origin-3d))
  (aspect wgpu-texture-aspect))

(defcstruct wgpu-future
  (id :uint64))

(defcstruct wgpu-future-wait-info
  (future (:struct wgpu-future))
  (completed wgpu-bool))

;; ============================================================================
;; wgpu.h native extension types
;; ============================================================================

(defcenum wgpu-log-level
  (:off #x0)
  (:error #x1)
  (:warn #x2)
  (:info #x3)
  (:debug #x4)
  (:trace #x5))

(defcenum wgpu-native-feature
  (:immediates #x00030001)
  (:texture-adapter-specific-format-features #x00030002)
  (:multi-draw-indirect-count #x00030004)
  (:vertex-writable-storage #x00030005)
  (:texture-binding-array #x00030006)
  (:sampled-texture-and-storage-buffer-array-non-uniform-indexing #x00030007)
  (:pipeline-statistics-query #x00030008)
  (:storage-resource-binding-array #x00030009)
  (:partially-bound-binding-array #x0003000A)
  (:texture-format-16bit-norm #x0003000B)
  (:texture-compression-astc-hdr #x0003000C)
  (:mappable-primary-buffers #x0003000E)
  (:buffer-binding-array #x0003000F)
  (:storage-texture-array-non-uniform-indexing #x00030010)
  (:polygon-mode-line #x00030013)
  (:polygon-mode-point #x00030014)
  (:conservative-rasterization #x00030015)
  (:clear-texture #x00030016)
  (:multiview #x00030018)
  (:vertex-attribute-64bit #x00030019)
  (:texture-format-nv12 #x0003001A)
  (:ray-query #x0003001C)
  (:shader-f64 #x0003001D)
  (:shader-i16 #x0003001E)
  (:shader-early-depth-test #x00030020)
  (:subgroup #x00030021)
  (:subgroup-vertex #x00030022)
  (:subgroup-barrier #x00030023)
  (:timestamp-query-inside-encoders #x00030024)
  (:timestamp-query-inside-passes #x00030025)
  (:shader-int64 #x00030026)
  (:shader-float32-atomic #x00030027)
  (:texture-atomic #x00030028)
  (:texture-format-p010 #x00030029)
  (:pipeline-cache #x0003002B)
  (:shader-int64-atomic-min-max #x0003002C)
  (:shader-int64-atomic-all-ops #x0003002D)
  (:texture-int64-atomic #x00030030)
  (:multisample-array #x0003003A)
  (:cooperative-matrix #x0003003B)
  (:shader-per-vertex #x0003003C)
  (:shader-draw-index #x0003003D)
  (:acceleration-structure-binding-array #x0003003E)
  (:memory-decoration-coherent #x0003003F)
  (:memory-decoration-volatile #x00030040))

(defcenum wgpu-instance-backend
  (:all 0)
  (:vulkan #x1)
  (:gl #x2)
  (:metal #x4)
  (:dx12 #x8)
  (:browser-webgpu #x20)
  (:primary #x2D)  ; Vulkan | Metal | DX12 | BrowserWebGPU
  (:secondary #x2))

(defcenum wgpu-dx12-compiler
  (:undefined #x0)
  (:fxc #x1)
  (:dxc #x2))

(defcstruct wgpu-instance-extras
  (chain (:struct wgpu-chained-struct))
  (backends wgpu-flags)
  (flags wgpu-flags)
  (dx12-shader-compiler wgpu-dx12-compiler)
  (gles3-minor-version :uint32)
  (gl-fence-behaviour :uint32)
  (dxc-path (:struct wgpu-string-view))
  (dxc-max-shader-model :uint32)
  (dx12-presentation-system :uint32)
  (budget-for-device-creation :pointer)
  (budget-for-device-loss :pointer)
  (display-handle :uint32)  ; Simplified
  )

(defcstruct wgpu-device-extras
  (chain (:struct wgpu-chained-struct))
  (trace-path (:struct wgpu-string-view)))

(defcstruct wgpu-native-limits
  (chain (:struct wgpu-chained-struct))
  (max-non-sampler-bindings :uint32)
  (max-binding-array-elements-per-shader-stage :uint32)
  (max-binding-array-sampler-elements-per-shader-stage :uint32)
  (max-multiview-view-count :uint32))

(defcstruct wgpu-pipeline-layout-extras
  (chain (:struct wgpu-chained-struct))
  (immediate-data-size :uint32))

(defcstruct wgpu-shader-source-glsl
  (chain (:struct wgpu-chained-struct))
  (stage wgpu-flags)
  (code (:struct wgpu-string-view))
  (define-count :uint32)
  (defines :pointer))

(defcstruct wgpu-shader-module-descriptor-spirv
  (label (:struct wgpu-string-view))
  (source-size :uint32)
  (source :pointer))

(defcstruct wgpu-image-subresource-range
  (aspect wgpu-texture-aspect)
  (base-mip-level :uint32)
  (mip-level-count :uint32)
  (base-array-layer :uint32)
  (array-layer-count :uint32))

(defcstruct wgpu-registry-report
  (num-allocated :size)
  (num-kept-from-user :size)
  (num-released-from-user :size)
  (element-size :size))

(defcstruct wgpu-hub-report
  (adapters (:struct wgpu-registry-report))
  (devices (:struct wgpu-registry-report))
  (queues (:struct wgpu-registry-report))
  (pipeline-layouts (:struct wgpu-registry-report))
  (shader-modules (:struct wgpu-registry-report))
  (bind-group-layouts (:struct wgpu-registry-report))
  (bind-groups (:struct wgpu-registry-report))
  (command-buffers (:struct wgpu-registry-report))
  (render-bundles (:struct wgpu-registry-report))
  (render-pipelines (:struct wgpu-registry-report))
  (compute-pipelines (:struct wgpu-registry-report))
  (pipeline-caches (:struct wgpu-registry-report))
  (query-sets (:struct wgpu-registry-report))
  (buffers (:struct wgpu-registry-report))
  (textures (:struct wgpu-registry-report))
  (texture-views (:struct wgpu-registry-report))
  (samplers (:struct wgpu-registry-report)))

(defcstruct wgpu-global-report
  (surfaces (:struct wgpu-registry-report))
  (hub (:struct wgpu-hub-report)))
