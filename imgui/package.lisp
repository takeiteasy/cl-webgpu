;;;; cl-webgpu/imgui -- Dear ImGui rendering backend for the wgpu wrapper.
;;;;
;;;; Unlike cl-webgpu/nuklear, this package does NOT forward the binding
;;;; library's symbols under a stripped prefix: cl-dear-imgui already exports
;;;; idiomatic short names, ~1650 of them, and many collide hard with the CL
;;;; package (RENDER, BEGIN, END, IO, KEY, COL, DIR, ...). Callers use a
;;;; local nickname instead, e.g.
;;;;
;;;;   (defpackage #:my-app
;;;;     (:use #:cl #:cl-webgpu/wrapper)
;;;;     (:local-nicknames (#:ig #:cl-dear-imgui)))
;;;;
;;;; and reach ImGui itself as IG:BEGIN, IG:TEXT, IG:SHOW-DEMO-WINDOW, etc.
;;;; cl-dear-imgui's struct SLOT names are not exported, so slot access uses
;;;; the double-colon form: (cffi:foreign-slot-value dd '(:struct ig:draw-data)
;;;; 'cl-dear-imgui::cmd-lists) -- mirrors the nuklear:: usage in
;;;; cl-webgpu/nuklear.

(defpackage #:cl-webgpu/imgui
  (:use #:cl)
  (:local-nicknames (#:ig #:cl-dear-imgui)
                    (#:w  #:cl-webgpu/wrapper))
  (:export #:make-imgui-renderer
           #:render-imgui
           #:free-imgui-renderer
           #:imgui-renderer
           #:imgui-renderer-p))
