# cl-webgpu/imgui — Dear ImGui GUI Backend

`cl-webgpu/imgui` integrates [Dear ImGui](https://github.com/ocornut/imgui)
(1.92, via [cl-dear-imgui](https://github.com/takeiteasy/cl-dear-imgui)) with
the wgpu rendering backend. It is the immediate-mode-GUI peer of
[`cl-webgpu/nuklear`](nuklear.md).

## Dependencies

- `cl-dear-imgui` — CFFI bindings for Dear ImGui via dear_bindings. Symlink
  `../cl-dear-imgui` into `~/quicklisp/local-projects/`, and build its native
  library first (`cd ../cl-dear-imgui && git submodule update --init && make`).
- `cl-webgpu/wrapper` — the CLOS wrapper layer.

## No symbol forwarding — use a local nickname

Unlike `cl-webgpu/nuklear`, this package does **not** re-export the binding
library's symbols under a stripped prefix. `cl-dear-imgui` already exports
idiomatic short names, ~1650 of them, and many collide with `COMMON-LISP`
(`render`, `begin`, `end`, `io`, `key`, `col`, `dir`, …). Reach ImGui through a
local nickname instead:

```lisp
(defpackage #:my-app
  (:use #:cl #:cl-webgpu/wrapper)
  (:local-nicknames (#:ig #:cl-dear-imgui)))

(ig:begin "Panel" (cffi:null-pointer) 0)
(ig:text "hello")
(ig:end)
```

`cl-dear-imgui` exports struct **type** names but not slot names, so struct
access uses the double-colon form
(`(cffi:foreign-slot-value dd '(:struct ig:draw-data) 'cl-dear-imgui::cmd-lists)`)
— the same shape as the `nuklear::` usage in `cl-webgpu/nuklear`.

## Backend API

```lisp
(make-imgui-renderer device queue surface-format &key label)  ; → imgui-renderer
```

Creates the pipeline, projection uniform, sampler and the two growable
vertex/index buffers, and sets `ImGuiBackendFlags_RendererHasTextures` +
`RendererHasVtxOffset` on the IO. **No atlas arguments** — under ImGui 1.92 the
font atlas arrives through the per-frame texture list like any other texture.

Call order is fixed:

```
(ig:create-context (cffi:null-pointer))   ; 1. context
(make-imgui-renderer device queue fmt)    ; 2. renderer (sets the backend flag)
;; ... then the first (ig:new-frame) via IMGUI-NEW-FRAME
```

Do **not** also drive the legacy `ImFontAtlas` `Build()` /
`GetTexDataAsRGBA32()` path — ImGui asserts if the atlas is built before the
flag is set.

```lisp
(render-imgui renderer draw-data pass queue)
```

Call once per frame, inside the render pass, before `end-and-submit`, with
`draw-data` from `(ig:get-draw-data)` (after `(ig:render)`). It:

1. services `ImDrawData::Textures` — create / update / destroy — first, always;
2. re-uploads the ortho projection from `DisplayPos` / `DisplaySize`;
3. concatenates every `ImDrawList`'s vertices and 16-bit indices into the two
   growable GPU buffers (one `write-buffer` each);
4. issues one scissored `draw-indexed` per `ImDrawCmd`, passing
   `VtxOffset` / `IdxOffset` as `:base-vertex` / `:first-index` and switching
   the group-1 bind group when the command's texture changes.

```lisp
(free-imgui-renderer renderer)
```

Releases every GPU resource, including all live ImGui textures.

## Vertex format

`ImDrawVert`, 20 bytes (stock `imconfig.h`, so RGBA in memory order → `unorm8x4`
with no swizzle, and `ImDrawIdx` is `uint16`):

| Offset | Type | Semantic |
|--------|------|----------|
| 0  | `vec2<f32>` | position (logical points) |
| 8  | `vec2<f32>` | UV |
| 16 | `unorm8x4`  | color (RGBA) |

## Render pipeline

| Group | Binding | Resource |
|-------|---------|----------|
| 0 | 0 | ortho projection uniform (`mat4x4<f32>`) |
| 0 | 1 | sampler (shared) |
| 1 | 0 | the draw command's `texture_2d<f32>` (one bind group per live texture) |

Premultiplied-alpha blending (`SRC_ALPHA` / `ONE_MINUS_SRC_ALPHA`).

## Texture lifecycle (`ImGuiBackendFlags_RendererHasTextures`)

Each frame `render-imgui` walks `ImDrawData::Textures` and honours each entry's
`Status`:

- **WantCreate** — `make-texture-2d` (`rgba8-unorm`), upload the whole image,
  build a group-1 bind group, assign a backend id, `SetTexID` + `SetStatus(OK)`.
- **WantUpdates** — `write-texture` the `UpdateRect` sub-region using the
  wrapper's `:x` / `:y` / `bytes-per-row` args (`GetPitch()` /
  `GetPixelsAt()`), then `SetStatus(OK)`.
- **WantDestroy** (once `UnusedFrames > 0`) — release the texture/view/bind
  group, `SetTexID(0)` + `SetStatus(Destroyed)`.

Because updates are serviced this way, runtime font-size changes (ImGui 1.92
dynamic scaling) work with no extra code.

## Input wiring

`cl-webgpu/imgui` only renders. Feeding input is a per-windowing-backend glue
system:

| System | Backend | File |
|---|---|---|
| `cl-webgpu/imgui-glfw-glue` | GLFW (`cl-webgpu/glfw`) | `imgui/glfw-input.lisp` |
| `cl-webgpu/imgui-sdl3-glue` | SDL3 (`cl-webgpu/sdl3`) | `imgui/sdl3-input.lisp` |

Both expose the same entry points:

```lisp
(install-input-callbacks window)   ; register scroll/text callbacks once
(imgui-new-frame window)           ; each frame, after the event pump; also calls (ig:new-frame)
(remove-input-callbacks)           ; on shutdown
```

`remove-input-callbacks` unregisters the SDL3 event watch; on GLFW it is a
no-op (GLFW drops per-window callbacks when the window is destroyed) kept for
call-site parity.

`imgui-new-frame` sets `DisplaySize` (logical points), `DisplayFramebufferScale`
(pixels per point) and a monotonic `DeltaTime`, pushes the cursor position and
polls the tracked mouse buttons and keys, then calls `ig:new-frame`. Scroll and
typed text are pushed straight into ImGui's event queue from the backend
callback / event watch — ImGui queues and de-duplicates, so there is no
accumulate-then-drain step (the Nuklear glue needs one; this does not).

Because ImGui keeps widget geometry in logical points with the framebuffer
scale separate, the ImGui demos need **no `*ui-scale*` fudge** — contrast the
Nuklear demos, whose projection is in raw framebuffer pixels.

### Shared plumbing — `cl-webgpu/imgui-input-common`

Both glue systems depend on `cl-webgpu/imgui-input-common`
(`imgui/input-common.lisp`): `*debug-input*`, the `DeltaTime` clock
(`reset-clock`), and `pump-imgui-frame`, which does the per-frame IO
bookkeeping and takes the backend-specific pieces as closures/alists
(`:pixel-size`, `:point-size`, `:cursor-position`, `:tracked-buttons` +
`:button-pressed-p`, `:tracked-keys` + `:key-pressed-p`).

The clock is process-global, so one window's timing at a time — fine for the
single-window demos. SDL3's glue uses a non-destructive `SDL_AddEventWatch`, so
the app's own event loop still sees every event.

## Example usage

- `examples/imgui-demo.lisp` — GLFW window: the ImGui demo window plus a custom
  slider + button, real input via `cl-webgpu/imgui-glfw-glue`.
- `examples/imgui-demo-sdl3.lisp` — the same on SDL3 via
  `cl-webgpu/imgui-sdl3-glue` (see [sdl3.md](sdl3.md)).

```lisp
(ql:quickload '(:cl-webgpu/wrapper :cl-webgpu/glfw
                :cl-webgpu/imgui :cl-webgpu/imgui-glfw-glue))

(ig:create-context (cffi:null-pointer))
(let ((renderer (cl-webgpu/imgui:make-imgui-renderer device queue surface-format)))
  (cl-webgpu/imgui-glfw-glue:install-input-callbacks window)
  (loop until (cl-webgpu/glfw:window-should-close-p window) do
    (cl-webgpu/glfw:poll-events)
    (cl-webgpu/imgui-glfw-glue:imgui-new-frame window)   ; also calls (ig:new-frame)
    (ig:show-demo-window (cffi:null-pointer))
    (ig:render)
    (with-render-pass (pass encoder view)
      (cl-webgpu/imgui:render-imgui renderer (ig:get-draw-data) pass queue)
      (end-and-submit encoder pass queue surface))))
```

## Known limitations / follow-up tickets

- **`user_callback` draw commands are skipped**, including the
  `ImDrawCallback_ResetRenderState` sentinel. Custom-draw callbacks and
  backend-state resets are not run. Tracked separately.
- **Single window / single ImGui context.** The `DeltaTime` clock and the
  input callbacks are process-global; multi-viewport / docking is not wired up.
