;;;; cl-webgpu.asd

(asdf:defsystem #:cl-webgpu
  :description "Common Lisp FFI bindings for WebGPU via wgpu-native"
  :author "George Watson <gigolo@hotmail.co.uk>"
  :license "MIT"
  :version "0.0.1"
  :serial t
  :depends-on (#:cffi)
  :components ((:module "src"
                :components
                ;; All files except library.lisp are AUTO-GENERATED.
                ;; Run (cl-webgpu-codegen:generate) to regenerate.
                ((:file "package")
                 (:file "library")
                 (:file "types")
                 (:file "functions")
                 (:file "functions-shim")))))

(asdf:defsystem #:cl-webgpu/glfw
  :description "GLFW integration for cl-webgpu"
  :author "George Watson <gigolo@hotmail.co.uk>"
  :license "MIT"
  :version "0.0.1"
  :serial t
  :depends-on (#:cl-webgpu)
  :components ((:module "src/glfw"
                :components
                ((:file "package")
                 (:file "library")
                 (:file "bindings")))))

(asdf:defsystem #:cl-webgpu/codegen
  :description "Code generator for cl-webgpu CFFI bindings from C headers"
  :author "George Watson <gigolo@hotmail.co.uk>"
  :license "MIT"
  :version "0.0.1"
  :serial t
  :depends-on (#:cl-ppcre #:uiop)
  :components ((:module "codegen"
                :components
                ((:file "package")
                 (:file "name-transformer")
                 (:file "c-parser")
                 (:file "lisp-generator")
                 (:file "main")))))
