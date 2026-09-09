;;;; sdl3/package.lisp

(defpackage #:cl-webgpu/sdl3
  (:use #:cl #:cffi)
  (:export #:load-sdl3-library
           #:sdl-get-wgpu-surface))

;; Forward-export every external symbol from cl-sdl3 (the SDL3 package is
;; named #:sdl3) so callers can use cl-webgpu/sdl3 as a drop-in replacement
;; without a direct dependency on sdl3 in their own package definitions.
(eval-when (:compile-toplevel :load-toplevel :execute)
  (do-external-symbols (s :sdl3)
    (import s :cl-webgpu/sdl3)
    (export s :cl-webgpu/sdl3)))
