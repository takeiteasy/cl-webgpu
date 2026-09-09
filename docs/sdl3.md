# SDL3 backend — `cl-webgpu/sdl3`

Creates a `WGPUSurface` from an SDL3 window, so an SDL3 application can render
with wgpu. It is the SDL3 counterpart of `cl-webgpu/glfw`: a thin system that
hands you a surface handle and forwards the windowing library's symbols — the
rest of your code stays windowing-agnostic (see the render-target seam in
[headless.md](headless.md); a real `GPU-SURFACE` works the same whether GLFW or
SDL3 created it).

## Dependencies

- `cl-webgpu` — base FFI bindings
- `sdl3` — CFFI bindings for SDL3 (package `#:sdl3`; symlink [cl-sdl3](https://github.com/ellisvelo/cl-sdl3) into `~/quicklisp/local-projects/`)
- Native SDL3 (`brew install sdl3`, or your platform's package)
- `shim/libSDL3_webgpu.{dylib,so,dll}` — the vendored C bridge, built by `make`

## The C bridge

`deps/sdl3webgpu/` vendors [sdl3webgpu](https://github.com/eliemichel/sdl3webgpu)
(`sdl3webgpu.c` / `.h`, MIT). `make` compiles it to `shim/libSDL3_webgpu.*`.

Like the `glfw3webgpu` bridge, it is linked with `-undefined dynamic_lookup`
(macOS) / plain `-shared` (elsewhere) and pulls in no SDL3 of its own — it
binds `SDL_*` at load time against whatever SDL3 the process already loaded
(cl-sdl3 does that when `#:sdl3` is quickloaded). On macOS it is built with
`-x objective-c` and the Cocoa / QuartzCore / Metal frameworks so it can pull
the `NSWindow`, attach a `CAMetalLayer`, and create a Metal-layer surface.

## Symbol forwarding

Every external symbol of the `#:sdl3` package is imported and re-exported from
`cl-webgpu/sdl3`, so callers can `(:use #:cl-webgpu/sdl3)` (or `:import-from`
it) without a direct dependency on `#:sdl3` in their own package definition —
exactly as `cl-webgpu/glfw` forwards `cl-glfw3`.

## API

```lisp
(load-sdl3-library &key path)
```

Pushes `path` onto `cffi:*foreign-library-directories*` (typically your
`shim/` directory) and loads `libSDL3_webgpu`. SDL3 itself is loaded by
cl-sdl3; this only loads the bridge. Call after `cl-webgpu:load-wgpu-libraries`.

```lisp
(sdl-get-wgpu-surface instance window) → wgpu-surface
```

Wraps `SDL_GetWGPUSurface`. `instance` is a raw `WGPUInstance` handle (e.g.
`(cl-webgpu/wrapper:handle inst)`); `window` is a cl-sdl3 window wrapper or a
raw `SDL_Window*` pointer. Returns a `WGPUSurface` handle — wrap it in a
`gpu-surface` for the wrapper layer:

```lisp
(make-instance 'cl-webgpu/wrapper:gpu-surface
               :handle (sdl-get-wgpu-surface (handle inst) window))
```

## HiDPI

Create the window with the `:high-pixel-density` flag and drive the surface /
projection off `SDL_GetWindowSizeInPixels` (framebuffer pixels), not
`sdl3:get-window-size` (logical points). Configuring at the point size renders
into a fraction of the real framebuffer, which the compositor upscales — soft
edges and mushy text. See the `*ui-scale*` note in
`examples/nuklear-static-sdl3.lisp`.

## macOS main-thread requirement

SDL3 must be initialised and pumped on the process main thread. On SBCL that
means launching through `sdl3:make-this-thread-main`:

```lisp
#+sbcl (sdl3:make-this-thread-main #'run)
#-sbcl (run)
```

`run` then calls `(sdl3:init :video)` … `(sdl3:quit)` directly; the main-thread
message loop keeps running until `sdl3:quit` is handled.

## Known issue — cl-sdl3 `mouse-state`

cl-sdl3's `mouse-state` / `get-global-mouse-state` bind `SDL_GetMouseState`'s
`x`/`y` out-params as `int*`, but SDL3 changed them to `float*` — so they
return garbage coordinates. `cl-webgpu/nuklear-sdl3-glue` binds
`SDL_GetMouseState` itself with the correct types as a workaround. If you call
`SDL_GetMouseState` directly, do the same.

## Example

`examples/nuklear-static-sdl3.lisp` — a full interactive demo: an SDL3 window,
a wgpu surface, a Nuklear panel with a live slider and button, and real
mouse/keyboard input via `cl-webgpu/nuklear-sdl3-glue` (see
[nuklear.md](nuklear.md)). It is a direct port of `examples/nuklear-static.lisp`
(the GLFW version).
