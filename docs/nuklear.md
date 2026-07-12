# cl-webgpu/nuklear — Nuklear GUI Backend

`cl-webgpu/nuklear` integrates the [Nuklear](https://github.com/Immediate-Mode-UI/Nuklear)
immediate-mode GUI library with the wgpu rendering backend.

## Dependencies

- `cl-nuklear` — CFFI bindings for Nuklear (symlink into `~/quicklisp/local-projects/`)
- `cl-webgpu/wrapper` — CLOS wrapper layer

## Symbol forwarding

All symbols from `cl-nuklear` (package `nuklear`) are forwarded into `cl-webgpu/nuklear`
with the `NK-` prefix stripped. For example:

- `nuklear:nk-begin` → `cl-webgpu/nuklear:begin`
- `nuklear:nk-convert` → `cl-webgpu/nuklear:convert`
- `nuklear:with-context` → `cl-webgpu/nuklear:with-context`

CFFI struct/union type specifiers still use their full names (e.g. `(:struct nuklear::nk-rect)`)
since CFFI type keys are symbols in the originating package.

## Backend API

```lisp
(make-nuklear-renderer device queue width height surface-format
                       atlas atlas-pixels atlas-w atlas-h)
  → nuklear-renderer
```

Creates all GPU resources: vertex/index/uniform buffers, font atlas texture,
sampler, bind group, and render pipeline. Returns a `nuklear-renderer` struct.

- `atlas` — foreign `nk_font_atlas*` pointer after `nk-font-atlas-begin`
- `atlas-pixels` — pixel data pointer returned by `nk-font-atlas-bake`
- `atlas-w`, `atlas-h` — atlas dimensions in pixels
- `surface-format` — WGPUTextureFormat keyword (e.g. `:bgra8-unorm`)

```lisp
(render-nuklear renderer ctx pass width height queue)
```

Converts the Nuklear context to GPU buffers and issues draw calls on the render pass.
Call once per frame, after building your UI with `nk-begin`/`nk-end` etc., and before
`end-and-submit`. Clears the Nuklear context state after drawing.

```lisp
(free-nuklear-renderer renderer)
```

Releases all GPU resources held by the renderer. Call during cleanup.

## Vertex format

Each vertex is 20 bytes:

| Offset | Type | Semantic |
|--------|------|----------|
| 0 | `vec2<f32>` | position (pixels) |
| 8 | `vec2<f32>` | UV |
| 16 | `unorm8x4` | color (RGBA) |

## Render pipeline

The pipeline uses a raw WGSL shader with one bind group (group 0):

| Binding | Resource |
|---------|----------|
| 0 | Ortho projection uniform (`mat4x4<f32>`) |
| 1 | Font atlas texture (`texture_2d<f32>`) |
| 2 | Font atlas sampler |

Alpha blending is enabled (SRC_ALPHA / ONE_MINUS_SRC_ALPHA).

## Example usage

See `examples/nuklear-static.lisp` for a complete static demo (no input handling).

```lisp
(ql:quickload '(:cl-webgpu/wrapper :cl-webgpu/glfw :cl-webgpu/nuklear))

;; Init atlas and bake font
(cffi:with-foreign-objects ((ctx   '(:struct nuklear::nk-context))
                             (atlas '(:struct nuklear::nk-font-atlas))
                             (aw :int) (ah :int))
  (nuklear::nk-font-atlas-init-default atlas)
  (nuklear::nk-font-atlas-begin atlas)
  (let* ((font    (nuklear::nk-font-atlas-add-default atlas 13.0 (cffi:null-pointer)))
         (pixels  (nuklear::nk-font-atlas-bake atlas aw ah :nk-font-atlas-rgba32))
         (renderer (cl-webgpu/nuklear:make-nuklear-renderer
                    device queue 640 480 surface-format
                    atlas pixels (cffi:mem-ref aw :int) (cffi:mem-ref ah :int))))
    (nuklear::nk-font-atlas-cleanup atlas)
    (nuklear::nk-init-default ctx (cffi:foreign-slot-pointer font '(:struct nuklear::nk-font) 'nuklear::handle))
    ;; Render loop
    (loop do
      (nuklear::nk-begin ctx "Panel" rect flags)
      (nuklear::nk-label ctx "Hello!" :nk-text-left)
      (nuklear::nk-end ctx)
      (with-render-pass (pass encoder view)
        (cl-webgpu/nuklear:render-nuklear renderer ctx pass 640 480 queue))
      ...)))
```

## Known limitations / follow-up tickets

- **No input wiring** — mouse/keyboard events are not forwarded to Nuklear. See tracker for the input ticket.
- **Fixed buffer sizes** — vertex (512KB), index (128KB), and command (64KB) buffers are statically allocated. Complex UIs that overflow will silently clip. A dynamic resizing strategy is tracked separately.
- **Single font** — only the default Nuklear font is supported. Custom TTF fonts require extending `make-nuklear-renderer`.
