# Headless rendering — `cl-webgpu/headless`

Renders to an offscreen GPU target and reads the result back as a PNG,
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

Code written this way is windowing-agnostic: the same loop works against a
real `GPU-SURFACE` (GLFW-created today, SDL3-created tomorrow — each backend
is just a system that hands you a `GPU-SURFACE`) or a `HEADLESS-TARGET` from
this package. Swap which one `target` is bound to and nothing else changes.

## The headless target

```lisp
(make-headless-target device width height &key (format :rgba8-unorm))
  → HEADLESS-TARGET
```

Creates a persistent `WIDTH`x`HEIGHT` texture (`RENDER_ATTACHMENT | COPY_SRC`
usage) implementing `ACQUIRE-FRAME-TEXTURE-VIEW`/`PRESENT-FRAME`. Release it
like any other GPU handle when done.

```lisp
(with-headless-frame (pass device queue target :clear-r 1.0 :clear-g 0.0)
  ...)
```

Renders one frame into `TARGET`: acquires the view, opens a render pass bound
to `PASS` (options go to `BEGIN-RENDER-PASS`), runs the body (draw calls
only), ends the pass, submits, releases the view, and presents. The body must
not call `SUBMIT-COMMANDS` itself — the macro submits exactly once after the
body returns. For multiple render passes per frame, drop to the primitives as
shown above.

```lisp
(readback-texture-png device queue target path) → path
```

Reads `TARGET`'s current contents back from the GPU (handles wgpu's
256-byte row-alignment requirement internally) and writes them to `PATH` as
a PNG. Blocks until the readback completes. Only `:RGBA8-UNORM` targets are
supported.

## Full example

```lisp
(ql:quickload :cl-webgpu/headless)

;; ... create instance/adapter/device as usual ...

(let ((target (cl-webgpu/headless:make-headless-target device 800 600))
      (queue  (make-instance 'gpu-queue :handle (wgpu-device-get-queue (handle device)))))
  (unwind-protect
      (progn
        (cl-webgpu/headless:with-headless-frame (pass device queue target
                                                 :clear-r 0.1d0 :clear-g 0.1d0 :clear-b 0.3d0)
          ;; your app's draw calls go here
          )
        (cl-webgpu/headless:readback-texture-png device queue target "/tmp/frame.png"))
    (release queue)
    (release target)))
```

`examples/headless-triangle.lisp` is a complete runnable example (renders a
triangle headlessly and writes a PNG to `/tmp`). `tests/wrapper-tests.lisp`
contains a smoke test that renders a frame and asserts on the readback pixels.
