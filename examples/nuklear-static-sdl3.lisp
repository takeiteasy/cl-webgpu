;;;; examples/nuklear-static-sdl3.lisp
;;;; Nuklear GUI rendered via cl-webgpu/nuklear — interactive demo, SDL3 backend.
;;;; The SDL3 counterpart of examples/nuklear-static.lisp: a panel with a label,
;;;; a live slider, and a button, driven by real SDL3 mouse/keyboard input via
;;;; cl-webgpu/nuklear-sdl3-glue.

(ql:quickload '(:cl-webgpu :cl-webgpu/wrapper :cl-webgpu/sdl3 :cl-webgpu/nuklear
                 :cl-webgpu/nuklear-sdl3-glue))

;; ============================================================================
;; Application package
;; ============================================================================

(defpackage #:nuklear-static-sdl3-example
  (:use #:cl #:cl-webgpu/wrapper)
  (:import-from #:cl-webgpu #:load-wgpu-libraries)
  (:import-from #:cl-webgpu/sdl3
                #:load-sdl3-library
                #:sdl-get-wgpu-surface)
  (:import-from #:cl-webgpu/nuklear-sdl3-glue
                #:install-input-callbacks
                #:remove-input-callbacks
                #:nuklear-new-frame))

(in-package #:nuklear-static-sdl3-example)

;; *WINDOW-WIDTH*/*HEIGHT* are in SDL3 "points" (what CREATE-WINDOW takes). On a
;; Retina display with the :HIGH-PIXEL-DENSITY flag the framebuffer is a denser
;; pixel grid -- *WIDTH*/*HEIGHT* below are set from SDL_GetWindowSizeInPixels
;; once the window exists, and are what CONFIGURE-SURFACE, MAKE-NUKLEAR-RENDERER,
;; and RENDER-NUKLEAR must use. Configuring at the point size instead renders
;; into a fraction of the real framebuffer, which the compositor upscales --
;; soft edges on solid shapes, and small glyph text turns to mush.
(defparameter *window-width*  640)
(defparameter *window-height* 480)
(defvar *width*)
(defvar *height*)
(defvar *slider-value* 0.5)

;; RENDER-NUKLEAR's projection is in framebuffer pixels, and nuklear treats
;; every widget-geometry number as a literal count of those pixels -- it has no
;; separate "point"/"logical" unit. *UI-SCALE* (framebuffer pixels per point)
;; corrects for this: multiply every layout constant and the baked font size by
;; it so the UI reads as a normal size regardless of display density.
(defvar *ui-scale* 1.0)

(defun load-libraries ()
  (let* ((base  (asdf:system-source-directory :cl-webgpu))
         (shim  (namestring (merge-pathnames #P"shim/" base)))
         (wgpu  (namestring (merge-pathnames #P"deps/wgpu-native/target/release/" base))))
    (cl-webgpu:load-wgpu-libraries :wgpu-path wgpu :shim-path shim)
    (load-sdl3-library :path shim)))

(defun window-pixel-size (window)
  "(VALUES PIXEL-W PIXEL-H) for WINDOW's framebuffer, via SDL3 directly."
  (cffi:with-foreign-objects ((w :int) (h :int))
    (sdl3-ffi.functions:sdl-get-window-size-in-pixels (autowrap:ptr window) w h)
    (values (cffi:mem-ref w :int) (cffi:mem-ref h :int))))

(defun render-frame (device surface queue renderer ctx)
  ;; Use the wrapper's own ACQUIRE-FRAME-TEXTURE-VIEW rather than hand-rolling
  ;; WGPU-TEXTURE-CREATE-VIEW here: the latter, called with a zero-initialized
  ;; descriptor, leaves MIP-LEVEL-COUNT / ARRAY-LAYER-COUNT at 0, which
  ;; wgpu-native rejects -- ACQUIRE-FRAME-TEXTURE-VIEW sets both to the "all"
  ;; sentinel, matching every other call site in the wrapper.
  (let ((view (acquire-frame-texture-view surface)))
    (when view
      (unwind-protect
          (with-gpu-command-encoder (encoder device)
            (with-render-pass (pass encoder view :clear-r 0.2d0 :clear-g 0.2d0 :clear-b 0.2d0)
              ;; NK-BEGIN and NK-BUTTON-LABEL's title/name params are typed
              ;; :POINTER (raw C strings) -- Lisp strings must go through
              ;; WITH-FOREIGN-STRING first, as NK-LABEL already does.
              (cffi:with-foreign-string (title "Demo")
                (nuklear::nk-begin ctx title
                                   (cffi:with-foreign-object (r '(:struct nuklear::nk-rect))
                                     (setf (cffi:foreign-slot-value r '(:struct nuklear::nk-rect) 'nuklear::x) (* 50.0 *ui-scale*)
                                           (cffi:foreign-slot-value r '(:struct nuklear::nk-rect) 'nuklear::y) (* 50.0 *ui-scale*)
                                           (cffi:foreign-slot-value r '(:struct nuklear::nk-rect) 'nuklear::w) (* 200.0 *ui-scale*)
                                           (cffi:foreign-slot-value r '(:struct nuklear::nk-rect) 'nuklear::h) (* 180.0 *ui-scale*))
                                     r)
                                   (logior 1 2 64))) ; border + movable + title
              ;; Nuklear requires a layout row before any widget -- without this,
              ;; the widgets below get a degenerate zero-size layout and draw
              ;; nothing.
              (nuklear::nk-layout-row-dynamic ctx (* 30.0 *ui-scale*) 1)
              ;; NK-LABEL's ALIGN param is a raw :UNSIGNED-INT bitmask, not the
              ;; NK-TEXT-ALIGNMENT enum type, so :NK-TEXT-LEFT needs an explicit
              ;; enum->integer lookup.
              (cffi:with-foreign-string (s "Hello from cl-webgpu/nuklear (SDL3)!")
                (nuklear::nk-label ctx s (cffi:foreign-enum-value 'nuklear::nk-text-alignment :nk-text-left)))
              (nuklear::nk-layout-row-dynamic ctx (* 30.0 *ui-scale*) 1)
              ;; Live slider proving real input: drag it and *SLIDER-VALUE* changes.
              (cffi:with-foreign-object (v :float)
                (setf (cffi:mem-ref v :float) (float *slider-value* 1.0))
                (nuklear::nk-slider-float ctx 0.0 v 1.0 0.01)
                (setf *slider-value* (cffi:mem-ref v :float)))
              (nuklear::nk-layout-row-dynamic ctx (* 30.0 *ui-scale*) 1)
              (cffi:with-foreign-string (btn "Click me")
                (when (plusp (nuklear::nk-button-label ctx btn))
                  (format t "Button clicked! slider = ~,2F~%" *slider-value*)))
              (nuklear::nk-end ctx)
              ;; Render to the pass.
              (cl-webgpu/nuklear:render-nuklear renderer ctx pass *width* *height* queue)
              ;; END-AND-SUBMIT must run inside WITH-RENDER-PASS's body: it calls
              ;; WGPU-RENDER-PASS-ENCODER-END on PASS, which only stays bound for
              ;; the dynamic extent of this body.
              (end-and-submit encoder pass queue surface)))
        (release view)))))

(defun poll-quit-p (ev)
  "Drain the SDL event queue; return T if a quit/close/ESC was seen. The
nuklear-sdl3-glue event watch has already skimmed scroll/text-input off each
event before we get here -- it does not consume them."
  (let ((quit nil))
    (loop while (/= 0 (sdl3:next-event ev :poll))
          do (case (sdl3:get-event-type ev)
               ((:quit :window-close-requested) (setf quit t))
               (:key-down
                (when (sdl3:scancode= (plus-c:c-ref ev sdl3-ffi:sdl-event :key :scancode)
                                      :escape)
                  (setf quit t)))))
    quit))

(defun run ()
  (load-libraries)
  #+sbcl (sb-int:set-floating-point-modes :traps nil)
  (sdl3:init :video)
  (let ((window (sdl3:create-window :title "Nuklear Static Demo (SDL3)"
                                    :w *window-width* :h *window-height*
                                    :flags '(:high-pixel-density))))
    (multiple-value-bind (px-w px-h) (window-pixel-size window)
      (setf *width* px-w *height* px-h)
      (setf *ui-scale* (float (/ px-w *window-width*) 1.0)))
    (sdl3:start-text-input window)
    (unwind-protect
        (with-gpu* ((inst    (make-gpu-instance))
                    (adapter (request-gpu-adapter inst))
                    (device  (request-gpu-device inst adapter))
                    (queue   (get-device-queue device))
                    (surface (make-instance 'gpu-surface
                                            :handle (sdl-get-wgpu-surface (handle inst) window))))
          (let ((fmt (get-surface-format surface adapter)))
            (configure-surface surface device fmt *width* *height*)
            ;; CTX is heap-allocated (not WITH-FOREIGN-OBJECTS) because
            ;; nk_context is ~18KB; SBCL forces large stack-allocated foreign
            ;; objects onto the C stack, which segfaults at that size.
            (let ((ctx (cffi:foreign-alloc '(:struct nuklear::nk-context))))
              (unwind-protect
                  (cffi:with-foreign-objects ((atlas '(:struct nuklear::nk-font-atlas))
                                              (aw    :int) (ah :int))
                    (nuklear::nk-font-atlas-init-default atlas)
                    (nuklear::nk-font-atlas-begin atlas)
                    (let* ((font   (nuklear::nk-font-atlas-add-default atlas (* 13.0 *ui-scale*) (cffi:null-pointer)))
                           (pixels (nuklear::nk-font-atlas-bake atlas aw ah :nk-font-atlas-rgba32))
                           (atlas-w (cffi:mem-ref aw :int))
                           (atlas-h (cffi:mem-ref ah :int))
                           (renderer (cl-webgpu/nuklear:make-nuklear-renderer
                                      device queue *width* *height* fmt
                                      atlas pixels atlas-w atlas-h)))
                      (nuklear::nk-font-atlas-cleanup atlas)
                      (let ((handle-ptr (cffi:foreign-slot-pointer font '(:struct nuklear::nk-font) 'nuklear::handle)))
                        (nuklear::nk-init-default ctx handle-ptr))
                      (install-input-callbacks window)
                      (unwind-protect
                          (sdl3:with-sdl-event (ev)
                            (format t "Running nuklear-static-sdl3 demo — drag the slider, close window or ESC to exit~%")
                            (loop until (poll-quit-p ev)
                                  do (nuklear-new-frame ctx window)
                                     (render-frame device surface queue renderer ctx)
                                     (sleep 0.016)))
                        (remove-input-callbacks)
                        (cl-webgpu/nuklear:free-nuklear-renderer renderer)
                        (nuklear::nk-free ctx)
                        (nuklear::nk-font-atlas-clear atlas))))
                (cffi:foreign-free ctx)))))
      (sdl3:destroy-window window)
      (sdl3:quit)
      (format t "Done.~%"))))

#+sbcl (sdl3:make-this-thread-main #'run)
#-sbcl (run)
