# cl-webgpu

Common Lisp FFI bindings for [WebGPU](https://www.w3.org/TR/webgpu/) via [wgpu-native](https://github.com/gfx-rs/wgpu-native).

## Overview

This project provides Common Lisp bindings to the WebGPU C API. Because the C API passes structs (especially `WGPUStringView`) by value in many places, which Common Lisp CFFI handles poorly, this project includes a **small C shim layer** that provides pointer-based alternatives.

## Project Structure

```
cl-webgpu/
├── cl-webgpu.asd          # ASDF system definition
├── shim/                  # C shim layer
│   ├── webgpu_shim.h      # Shim header
│   ├── webgpu_shim.c      # Shim implementation
│   └── Makefile           # Build the shim shared library
├── src/                   # Lisp FFI bindings
│   ├── package.lisp       # Package definition
│   ├── library.lisp       # CFFI foreign library loader
│   ├── types.lisp         # CFFI type definitions (enums, structs)
│   └── functions.lisp     # CFFI function bindings
├── deps/                  # Downloaded dependencies
│   ├── webgpu/            # webgpu.h + wgpu.h headers
│   └── wgpu-native/       # wgpu-native source (optional)
```

## Prerequisites

1. **Common Lisp with CFFI** - SBCL, CCL, etc. with [CFFI](https://common-lisp.net/project/cffi/) installed.
2. **C compiler** - `cc` or `gcc` or `clang`.
3. **wgpu-native shared library** - Download a prebuilt release or build from source.

## Building

### 1. Download wgpu-native binaries

Download the appropriate prebuilt binaries from the [wgpu-native releases page](https://github.com/gfx-rs/wgpu-native/releases).

Place the shared library (`libwgpu_native.dylib`, `libwgpu_native.so`, or `wgpu_native.dll`) somewhere on your library search path, or note its location.

### 2. Build the C shim

```bash
cd shim
make
```

This produces `libwebgpu_shim.dylib` (macOS), `libwebgpu_shim.so` (Linux), or `webgpu_shim.dll` (Windows).

**Note:** On macOS, the shim uses `-undefined dynamic_lookup` so it doesn't need to link against wgpu-native at build time. It will resolve symbols at runtime.

### 3. Load in Lisp

```lisp
(ql:quickload :cl-webgpu)

;; Load the libraries
(cl-webgpu:load-wgpu-libraries
  :wgpu-path "/path/to/wgpu-native/lib/"
  :shim-path "/path/to/cl-webgpu/shim/")
```

## Shim Layer Details

The shim layer wraps functions that pass structs by value:

### WGPUStringView -> (const char*, size_t)

All `SetLabel`, `InsertDebugMarker`, and `PushDebugGroup` functions now take a raw C string pointer + length instead of a `WGPUStringView` struct.

### FreeMembers -> pointer versions

`wgpuAdapterInfoFreeMembers`, `wgpuSupportedFeaturesFreeMembers`, etc. now take pointers instead of by-value structs.

### Callbacks -> decomposed signatures

All callbacks that received `WGPUStringView` by value now receive `(const char* data, size_t length)` instead. The shim internally translates between the two representations.

### Async functions -> decomposed callback info

Async functions like `wgpuBufferMapAsync` that took callback info structs by value now take the callback fields individually.

## API Coverage

The bindings cover:
- All core WebGPU object types (Device, Buffer, Texture, Pipeline, etc.)
- All enums and bitflags
- All struct definitions needed for descriptor creation
- All synchronous functions
- All async functions (via shim callbacks)
- wgpu-native extensions (extras, logging, enumeration, etc.)

## License

MIT License
