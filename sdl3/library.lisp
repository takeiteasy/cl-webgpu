;;;; sdl3/library.lisp

(in-package #:cl-webgpu/sdl3)

(cffi:define-foreign-library sdl3webgpu
  (:darwin (:or "libSDL3_webgpu.dylib" "SDL3_webgpu.dylib"))
  (:unix (:or "libSDL3_webgpu.so" "SDL3_webgpu.so"))
  (:windows (:or "SDL3_webgpu.dll" "libSDL3_webgpu.dll"))
  (t (:default "libSDL3_webgpu")))

(defun load-sdl3-library (&key path)
  "Push PATH onto cffi:*foreign-library-directories* and load libSDL3_webgpu.
   cl-sdl3 handles loading SDL3 itself; we only need the sdl3webgpu bridge,
   which binds to whatever SDL3 instance the process has already loaded."
  (when path
    (pushnew path cffi:*foreign-library-directories* :test #'equal))
  (cffi:load-foreign-library 'sdl3webgpu))

(cffi:defcfun ("SDL_GetWGPUSurface" %sdl-get-wgpu-surface) cl-webgpu:wgpu-surface
  (instance cl-webgpu:wgpu-instance)
  (window   :pointer))

(defun sdl-get-wgpu-surface (instance window)
  "Create a WGPUSurface for the SDL3 WINDOW under INSTANCE.
   WINDOW may be a cl-sdl3 window wrapper or a raw foreign pointer."
  (%sdl-get-wgpu-surface instance
                         (if (cffi:pointerp window)
                             window
                             (autowrap:ptr window))))
