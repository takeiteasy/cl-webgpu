# Headless rendering — `cl-webgpu/headless` + `cl-webgpu/glfw-dummy`

Renders to an offscreen GPU texture and reads the result back as a PNG,
without opening a window or touching a display server. Useful for testing
graphics changes over SSH/CI, where there's no screen to look at and (on
macOS) no screen-recording permission to grant to a remote process.

Rendering itself happens entirely on the GPU — no window, window server, or
screen capture is involved, so this sidesteps the usual "screenshot the app
over SSH" problems (locked/asleep screen, TCC permissions not carrying over
from an interactive session into an SSH one) entirely.

## Dependencies

- `cl-webgpu/wrapper` — CLOS wrapper layer
- `zpng` — PNG encoding (pulled from Quicklisp)

## The render-target seam

Write render loops against two generics from `cl-webgpu/wrapper` instead of
calling `wgpu-surface-*` directly:

- `(acquire-frame-texture-view target)` — returns a `GPU-TEXTURE-VIEW` for
  the current frame, or `NIL` if none is available yet (e.g. a surface
  texture that came back suboptimal). Release the view after rendering.
- `(present-frame target)` — presents (for a real `GPU-SURFACE`) or no-ops
  (for a headless target).

Both have a method for `GPU-SURFACE` already. Pair `SUBMIT-COMMANDS` (ends
the pass, finishes the encoder, submits — no present) with these two instead
of `END-AND-SUBMIT` when TARGET might not be a real surface:

```lisp
(let ((view (acquire-frame-texture-view target)))
  (when view
    (unwind-protect
        (with-gpu-command-encoder (encoder device)
          (with-render-pass (pass encoder view :clear-r 0.05d0 :clear-g 0.05d0 :clear-b 0.1d0)
            (submit-commands encoder pass queue)))
      (release view))
    (present-frame target)))
```

Code written this way works unmodified against either a real `GPU-SURFACE`
or a `GPU-OFFSCREEN-TARGET` — swap which one `target` is bound to and
nothing else changes. `rpg`'s `game/app.lisp` (in the sibling `rpg` repo)
is a worked example of exactly this refactor.

## `cl-webgpu/headless`: the offscreen target

```lisp
(make-offscreen-target device width height &key (format :rgba8-unorm))
  → GPU-OFFSCREEN-TARGET
```

Creates a persistent `WIDTH`x`HEIGHT` texture (`RENDER_ATTACHMENT | COPY_SRC`
usage) implementing `ACQUIRE-FRAME-TEXTURE-VIEW`/`PRESENT-FRAME`. Release it
like any other GPU handle when done.

```lisp
(readback-texture-png device queue target path) → path
```

Reads `TARGET`'s current contents back from the GPU (handles wgpu's
256-byte row-alignment requirement internally) and writes them to `PATH` as
a PNG. Blocks until the readback completes. Only `:RGBA8-UNORM` targets are
supported.

## `cl-webgpu/glfw-dummy`: terminating an existing window loop headlessly

Most app loops are shaped like:

```lisp
(loop until (glfw:window-should-close-p window)
      do (glfw:poll-events)
         (render-frame ...))
```

`cl-webgpu/glfw-dummy` implements the same call names
(`initialize`, `create-window`, `window-should-close-p`, `poll-events`,
`destroy-window`, `terminate`, `get-primary-monitor`) without opening a real
window. `window-should-close-p` starts returning `T` once `poll-events` has
been called `*frame-budget*` times (default 1) — rebind `*frame-budget*`
before `create-window` to render more than one frame headless. This lets an
existing loop terminate on its own after a fixed number of frames instead of
needing a real window's close event, so the loop body doesn't need an
`:headless` branch of its own — only the target (surface vs. offscreen) and
which GLFW package the loop's calls are qualified with need to change.

## Full example

```lisp
(ql:quickload :cl-webgpu/headless)
(ql:quickload :cl-webgpu/glfw-dummy)

;; ... create instance/adapter/device as usual ...

(let ((target (cl-webgpu/headless:make-offscreen-target device 800 600))
      (queue  (make-instance 'gpu-queue :handle (wgpu-device-get-queue (handle device)))))
  (unwind-protect
      (progn
        (render-frame device target queue) ; your app's render loop body
        (cl-webgpu/headless:readback-texture-png device queue target "/tmp/frame.png"))
    (release queue)
    (release target)))
```

## Adopting this in another app

Anything built on `cl-webgpu/wrapper` that currently calls
`wgpu-surface-get-current-texture`/`wgpu-surface-present` directly (like
`weasel`'s `core/window.lisp`) can get headless support for free by
switching to `acquire-frame-texture-view`/`submit-commands`/`present-frame`
— no behavior change for the existing windowed path, since those functions
already have `GPU-SURFACE` methods matching what the direct calls did.
