;;;; examples/nuklear-static.lisp
;;;; Nuklear GUI rendered via cl-webgpu/nuklear — static demo (no input handling).
;;;; Displays a panel with a label and a button using fixed synthetic state.

(ql:quickload '(:cl-webgpu :cl-webgpu/wrapper :cl-webgpu/glfw :cl-webgpu/nuklear))

;; ============================================================================
;; Application package
;; ============================================================================

(defpackage #:nuklear-static-example
  (:use #:cl #:cl-webgpu/wrapper)
  (:import-from #:cl-webgpu #:load-wgpu-libraries)
  (:import-from #:cl-webgpu/glfw
                #:initialize #:terminate
                #:create-window #:destroy-window
                #:poll-events #:window-should-close-p
                #:get-framebuffer-size
                #:glfw-create-window-wgpu-surface
                #:load-glfw-library))

(in-package #:nuklear-static-example)

;; WINDOW-WIDTH/HEIGHT are in GLFW "points" (what CREATE-WINDOW takes). On a
;; Retina display the framebuffer is a 2x-denser pixel grid than the window's
;; point size -- *WIDTH*/*HEIGHT* below are set from GET-FRAMEBUFFER-SIZE once
;; the window exists, and are what CONFIGURE-SURFACE, MAKE-NUKLEAR-RENDERER,
;; and RENDER-NUKLEAR must use. Configuring the surface / nuklear projection
;; at the point size instead renders into a quarter of the actual framebuffer,
;; which the compositor then upscales 2x -- soft edges on solid shapes, and
;; small glyph text turns to mush.
(defparameter *window-width*  640)
(defparameter *window-height* 480)
(defvar *width*)
(defvar *height*)

(defun load-libraries ()
  (let* ((base  (asdf:system-source-directory :cl-webgpu))
         (shim  (namestring (merge-pathnames #P"shim/" base)))
         (wgpu  (namestring (merge-pathnames #P"deps/wgpu-native/target/release/" base))))
    (cl-webgpu:load-wgpu-libraries :wgpu-path wgpu :shim-path shim)
    (load-glfw-library :path shim)))

(defun render-frame (device surface pipeline queue renderer ctx)
  ;; Use the wrapper's own ACQUIRE-FRAME-TEXTURE-VIEW (wrapper/wrapper.lisp)
  ;; rather than hand-rolling WGPU-TEXTURE-CREATE-VIEW here: the latter, called
  ;; with a zero-initialized WGPU-TEXTURE-VIEW-DESCRIPTOR, leaves MIP-LEVEL-COUNT
  ;; and ARRAY-LAYER-COUNT at 0, which wgpu-native rejects ("invalid
  ;; mipLevelCount") -- ACQUIRE-FRAME-TEXTURE-VIEW already sets both to the
  ;; #xFFFFFFFF "all" sentinel, matching every other call site in the wrapper.
  (let ((view (acquire-frame-texture-view surface)))
    (when view
      (unwind-protect
          (with-gpu-command-encoder (encoder device)
            (with-render-pass (pass encoder view :clear-r 0.2d0 :clear-g 0.2d0 :clear-b 0.2d0)
              ;; Build synthetic UI (no input — just static geometry).
              ;; NK-BEGIN and NK-BUTTON-LABEL's title/name params are typed
              ;; :POINTER (raw C strings, not CFFI :STRING) -- Lisp strings
              ;; must go through WITH-FOREIGN-STRING first, as NK-LABEL already does.
              (cffi:with-foreign-string (title "Demo")
                (nuklear::nk-begin ctx title
                                   (cffi:with-foreign-object (r '(:struct nuklear::nk-rect))
                                     (setf (cffi:foreign-slot-value r '(:struct nuklear::nk-rect) 'nuklear::x) 50.0
                                           (cffi:foreign-slot-value r '(:struct nuklear::nk-rect) 'nuklear::y) 50.0
                                           (cffi:foreign-slot-value r '(:struct nuklear::nk-rect) 'nuklear::w) 200.0
                                           (cffi:foreign-slot-value r '(:struct nuklear::nk-rect) 'nuklear::h) 150.0)
                                     r)
                                   (logior 1 2 64))) ; border + movable + title
              ;; Nuklear requires a layout row to be established before adding
              ;; any widget to a window body -- without this, NK-LABEL and
              ;; NK-BUTTON-LABEL below get a degenerate zero-size layout and
              ;; draw nothing.
              (nuklear::nk-layout-row-dynamic ctx 30.0 1)
              ;; NK-LABEL's ALIGN param is a raw :UNSIGNED-INT bitmask, not the
              ;; NK-TEXT-ALIGNMENT enum type, so the :NK-TEXT-LEFT keyword needs
              ;; an explicit enum->integer lookup rather than relying on CFFI to
              ;; coerce it (it only does that for arguments typed as the enum).
              (cffi:with-foreign-string (s "Hello from cl-webgpu/nuklear!")
                (nuklear::nk-label ctx s (cffi:foreign-enum-value 'nuklear::nk-text-alignment :nk-text-left)))
              (nuklear::nk-layout-row-dynamic ctx 30.0 1)
              (cffi:with-foreign-string (btn "Click me")
                (nuklear::nk-button-label ctx btn))
              (nuklear::nk-end ctx)
              ;; Render to the pass
              (cl-webgpu/nuklear:render-nuklear renderer ctx pass *width* *height*
                                                (make-instance 'gpu-queue :handle
                                                               (cl-webgpu:wgpu-device-get-queue (handle device))))
              ;; END-AND-SUBMIT must run here, inside WITH-RENDER-PASS's body: it
              ;; calls WGPU-RENDER-PASS-ENCODER-END on PASS, and PASS only stays
              ;; bound (and un-released) for the dynamic extent of this body --
              ;; WITH-RENDER-PASS releases it on the way out. Calling it after
              ;; WITH-RENDER-PASS returns, as this example previously did, left
              ;; PASS unbound (a compiler warning that was going unheeded) and
              ;; would in any case have raced WITH-RENDER-PASS's own release.
              (let ((q (make-instance 'gpu-queue :handle (cl-webgpu:wgpu-device-get-queue (handle device)))))
                (end-and-submit encoder pass q surface))))
        (release view)))))

(defun run ()
  (load-libraries)
  #+sbcl (sb-int:set-floating-point-modes :traps nil)
  (cl-glfw3:initialize)
  (let ((window (cl-glfw3:create-window :width *window-width* :height *window-height*
                                        :title "Nuklear Static Demo"
                                        :client-api :no-api
                                        :resizable nil)))
    (destructuring-bind (fb-width fb-height) (get-framebuffer-size window)
      (setf *width* fb-width *height* fb-height))
    (unwind-protect
        (with-gpu-instance (inst)
          (with-gpu-adapter (adapter inst)
            (with-gpu-device (device inst adapter)
              (let* ((raw-surface (glfw-create-window-wgpu-surface (handle inst) window))
                     (surface     (make-instance 'gpu-surface :handle raw-surface))
                     (fmt         (get-surface-format surface adapter)))
                (unwind-protect
                    (progn
                      (configure-surface surface device fmt *width* *height*)
                      ;; Init nuklear context with default font atlas.
                      ;; CTX is heap-allocated (not WITH-FOREIGN-OBJECTS) because
                      ;; nk_context is ~18KB; SBCL's CFFI forces large stack-allocated
                      ;; foreign objects onto the C stack, which segfaults at that size.
                      (let ((ctx (cffi:foreign-alloc '(:struct nuklear::nk-context))))
                       (unwind-protect
                        (cffi:with-foreign-objects ((atlas '(:struct nuklear::nk-font-atlas))
                                                    (aw    :int) (ah :int))
                        (nuklear::nk-font-atlas-init-default atlas)
                        (nuklear::nk-font-atlas-begin atlas)
                        (let* ((font   (nuklear::nk-font-atlas-add-default atlas 13.0 (cffi:null-pointer)))
                               (pixels (nuklear::nk-font-atlas-bake atlas aw ah :nk-font-atlas-rgba32))
                               (atlas-w (cffi:mem-ref aw :int))
                               (atlas-h (cffi:mem-ref ah :int))
                               (queue   (make-instance 'gpu-queue
                                                       :handle (cl-webgpu:wgpu-device-get-queue (handle device))))
                               (renderer (cl-webgpu/nuklear:make-nuklear-renderer
                                          device queue *width* *height* fmt
                                          atlas pixels atlas-w atlas-h)))
                          (nuklear::nk-font-atlas-cleanup atlas)
                          ;; Init context with the baked font
                          (let ((handle-ptr (cffi:foreign-slot-pointer font '(:struct nuklear::nk-font) 'nuklear::handle)))
                            (nuklear::nk-init-default ctx handle-ptr))
                          (unwind-protect
                              (progn
                                (format t "Running nuklear-static demo — close window to exit~%")
                                (loop until (window-should-close-p window)
                                      do (poll-events)
                                         (render-frame device surface nil queue renderer ctx)
                                         (sleep 0.016)))
                            (cl-webgpu/nuklear:free-nuklear-renderer renderer)
                            (nuklear::nk-free ctx)
                            (nuklear::nk-font-atlas-clear atlas)
                            (release queue))))
                        (cffi:foreign-free ctx))))
                  (release surface))))))
      (destroy-window window)
      (terminate)
      (format t "Done.~%"))))

(run)
