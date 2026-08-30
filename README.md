# cl-webgpu

Common Lisp FFI bindings for [WebGPU](https://www.w3.org/TR/webgpu/) via [wgpu-native](https://github.com/gfx-rs/wgpu-native).

## Requirements

- **SBCL** (or another CFFI-capable Lisp)
- **Quicklisp**
- **Rust / Cargo** — to build wgpu-native from source (or use a pre-built binary)
- **GLFW 3** — for windowed examples (install via Homebrew, apt, etc.)
- **C compiler** (`cc` / `clang` / `gcc`)
- **cl-nuklear** — required for `cl-webgpu/nuklear` only; symlink `../cl-nuklear` into `~/quicklisp/local-projects/`

## Building

### 1. Build wgpu-native

The vendored wgpu-native source in `deps/wgpu-native/` includes local patches from
`patches/` (registered in `dependencies.rb`). These are already applied to the vendored
source tree; you do not need to apply them manually.

```bash
cd deps/wgpu-native
cargo build --release
```

Or download a pre-built binary from the [wgpu-native releases page](https://github.com/gfx-rs/wgpu-native/releases) and place `libwgpu_native.{dylib,so,dll}` in `deps/wgpu-native/target/release/`.

### 2. Build the C shim + GLFW bridge

```bash
make        # builds libwebgpu_shim + libglfw3webgpu in shim/
```

The shim wraps functions that pass structs by value (e.g. `WGPUStringView`), which CFFI handles poorly. On macOS the shim uses `-undefined dynamic_lookup`, so it resolves wgpu-native symbols at runtime.

### 3. Load in Lisp

```lisp
(ql:quickload :cl-webgpu)

(cl-webgpu:load-wgpu-libraries
  :wgpu-path "deps/wgpu-native/target/release/"
  :shim-path "shim/")
```

## Quick Start

```lisp
;; Minimal triangle (raw bindings)
(load "examples/triangle.lisp")

;; Triangle with wrapper layer + shader DSL
(load "examples/triangle-wrapper.lisp")
```

## Systems

| System | Purpose |
|---|---|
| `cl-webgpu` | Auto-generated FFI bindings (types, enums, functions) |
| `cl-webgpu/glfw` | GLFW surface creation helper |
| `cl-webgpu/glfw-dummy` | Headless drop-in for `cl-webgpu/glfw`'s window/loop calls — no window, no display server |
| `cl-webgpu/wrapper` | CLOS wrapper layer — easy-to-use API |
| `cl-webgpu/headless` | Offscreen render target + PNG readback, for testing without a display (requires `zpng`) |
| `cl-webgpu/shader` | WGSL shader DSL |
| `cl-webgpu/nuklear` | Nuklear immediate-mode GUI backend (requires `cl-nuklear`) |
| `cl-webgpu/codegen` | Re-generates `cl-webgpu` bindings from C headers |

## Wrapper Layer (`cl-webgpu/wrapper`)

The wrapper eliminates the `foreign-alloc` / `foreign-slot-value` boilerplate by providing:

**CLOS handle classes** — each wraps a raw wgpu pointer and dispatches `release` to the correct `wgpu*Release` function. Every object a wrapper function returns is one of these — there's no raw-pointer escape hatch to remember to release by hand:

```
gpu-instance  gpu-adapter  gpu-device   gpu-surface
gpu-shader-module  gpu-render-pipeline  gpu-command-encoder
gpu-render-pass  gpu-texture-view  gpu-queue  gpu-buffer  gpu-texture
gpu-sampler  gpu-bind-group  gpu-bind-group-layout
```

**`with-gpu*`** — flat RAII scoping over any number of handles, without nesting a nine-deep nest of one-per-resource macros by hand. Bind `(var form)` for a single value or `((var1 var2) form)` for a form that returns multiple values (e.g. `make-texture-2d`); every bound variable is released in reverse order when the body exits, normally or via an error:

```lisp
(with-gpu* ((inst    (make-gpu-instance))
            (adapter (request-gpu-adapter inst))
            (device  (request-gpu-device inst adapter))
            (queue   (get-device-queue device))
            ((tex view) (make-texture-2d device 256 256)))
  ...)   ; view, tex, queue, device, adapter, inst all released on exit
```

The original one-resource-per-macro forms (`with-gpu-instance`, `with-gpu-adapter`, `with-gpu-device`, `with-gpu-shader-module`, `with-gpu-render-pipeline`, `with-gpu-command-encoder`, `with-render-pass`) still exist for the single-resource case:

```lisp
(with-gpu-instance (inst)
  ...)   ; inst released on exit, even on error
```

**`with-wgpu-struct`** — scoped zeroed foreign struct (no manual `foreign-alloc`/`foreign-free`):

```lisp
(with-wgpu-struct (desc '(:struct wgpu-render-pipeline-descriptor))
  (setf (foreign-slot-value desc ...) ...)
  ...)
```

**Creation helpers** hide descriptor boilerplate entirely:

```lisp
(make-gpu-instance)
(request-gpu-adapter instance &key power-preference backend)
(request-gpu-device  instance adapter &key label)
(get-device-queue    device)                        ; → gpu-queue
(make-shader-module  device wgsl-source &key label)
(get-surface-format  surface adapter)               ; → keyword e.g. :bgra8-unorm
(make-render-pipeline device &key vertex-module fragment-module
                              entry-point surface-format label)
(configure-surface   surface device format width height)
(make-command-encoder device &key label)
(begin-render-pass   encoder texture-view &key clear-r clear-g clear-b clear-a)
(end-and-submit      encoder pass queue surface)

;; buffers -- WRITE-BUFFER and MAKE-BUFFER-WITH-DATA take a Lisp vector
;; directly (single-float, (unsigned-byte 32), or (unsigned-byte 8)) and
;; do the foreign-alloc/copy/free internally; a foreign pointer + explicit
;; SIZE still works for callers that already have one.
(make-buffer device &key size usage mapped-at-creation label)   ; → gpu-buffer
(make-buffer-with-data device queue data usage &key label)      ; create + upload in one call
(write-buffer queue buffer offset data &optional size)

;; textures, samplers, bind groups
(make-texture-2d device width height &key format usage label)   ; → (values gpu-texture gpu-texture-view)
(write-texture   queue texture data data-size &key width height bytes-per-row)  ; DATA: pointer or (unsigned-byte 8) vector
(make-sampler    device &key mag-filter min-filter address-mode)     ; → gpu-sampler
(get-pipeline-bind-group-layout pipeline group-index)                 ; → gpu-bind-group-layout
(make-bind-group device layout entries)                               ; → gpu-bind-group
```

See `examples/triangle-wrapper.lisp` for a complete example.

## Shader DSL (`cl-webgpu/shader`)

> This is a fork of [3bgl-shaders](https://github.com/3b/3bgl-shaders) for WGSL shaders.

Write WGSL shaders in Common Lisp. The DSL compiles Lisp forms, infers types, and emits WGSL.

### Defining shaders

```lisp
(ql:quickload :cl-webgpu/shader)

;; Define a fragment colour output
(cl-webgpu/shader/internal:shader-output frag-color :vec4
  :stage :fragment :location 0)

;; Define fragment entry point
(cl-webgpu/shader/internal:shader-defun main ()
  (setf frag-color (vec4 1.0 0.5 0.0 1.0)))

;; Generate combined vertex+fragment WGSL string
(cl-webgpu/shader:generate-shader :vertex 'vs-main :fragment 'main)
```

### Key macros (in `cl-webgpu/shader/internal`)

| Macro | Purpose |
|---|---|
| `shader-defun name args &body` | Define a shader function |
| `shader-output name type &key stage location` | Declare a stage output |
| `shader-input name type &key stage location` | Declare a stage input |
| `shader-uniform name type &key stage group binding` | Declare a uniform |
| `shader-interface name (&key in out uniform) &body` | Declare an interface block |

### Built-in shader variables

Vertex: `vertex-index`, `instance-index`  
Fragment: `frag-position`, `front-facing`, `frag-depth`, `sample-index`  
Compute: `global-invocation-id`, `local-invocation-id`, `workgroup-id`, `num-workgroups`

### Entry point generation

`generate-shader` uses an "old-style" struct I/O convention. The vertex entry point
receives an auto-built `VertexInput` struct (from `:vertex` stage inputs) and returns
`VertexOutput` (always includes `@builtin(position)`). Vertex outputs flow through to
the fragment stage as `FragmentInput`.

```lisp
(defparameter *shader-src*
  (cl-webgpu/shader:generate-shader :vertex 'vs-main :fragment 'fs-main))

;; Then feed to the wrapper:
(make-shader-module device *shader-src* :label "My Shader")
```

### Compile/inspect separately

```lisp
;; Compile a single form into the shader IR
(cl-webgpu/shader:compile-form
  '(cl:defun vs-main () (setf position (vec4 0.0 0.0 0.0 1.0))))

;; Generate WGSL for one stage (also returns uniforms, attributes)
(cl-webgpu/shader:generate-stage :vertex 'vs-main)
```

## Regenerating Bindings

The files under `src/` (except `library.lisp`) are auto-generated from the C headers
in `deps/webgpu/`. After updating headers:

```lisp
(ql:quickload :cl-webgpu/codegen)
(cl-webgpu/codegen:generate)
```

## License

### Dependencies + vendored

- [3bgl-shaders](https://github.com/3b/3bgl-shaders) forked + modified (MIT)
- [wgpu-native](https://github.com/gfx-rs/wgpu-native) [MIT](https://github.com/gfx-rs/wgpu-native/blob/master/LICENSE.MIT)/[Apache 2.0](https://github.com/gfx-rs/wgpu-native/blob/master/LICENSE.APACHE)
- [webgpu-headers](https://github.com/webgpu-native/webgpu-headers) [BSD-3-Clause](https://github.com/webgpu-native/webgpu-headers/blob/master/LICENSE)
- [glfw3webgpu](https://github.com/eliemichel/glfw3webgpu) [MIT](https://github.com/eliemichel/glfw3webgpu/blob/master/LICENSE.txt)
- [glfw3](https://github.com/glfw/glfw) [ZLIB](https://github.com/glfw/glfw/blob/master/LICENSE)
- [Nuklear](https://github.com/Immediate-Mode-UI/Nuklear) [MIT](https://github.com/Immediate-Mode-UI/Nuklear/blob/master/LICENSE) (via [cl-nuklear](https://github.com/takeiteasy/cl-nuklear), for `cl-webgpu/nuklear`)
- Dependencies: [cl-glfw3](https://github.com/AlexCharlton/cl-glfw3) (for `cl-webgpu/glfw`), [zpng](https://github.com/xach/zpng) (for `cl-webgpu/headless`), cffi, bordeaux-threads, alexandria, cl-ppcre, uiop

[MIT](LICENSE)
