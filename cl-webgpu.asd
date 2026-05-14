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
                ;; Run (cl-webgpu/codegen:generate) to regenerate.
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
  :depends-on (#:cl-webgpu #:cl-glfw3)
  :components ((:module "glfw"
                :components
                ((:file "package")
                 (:file "library")))))

(asdf:defsystem #:cl-webgpu/shader
  :description "WGSL shader DSL for cl-webgpu"
  :author "George Watson <gigolo@hotmail.co.uk>"
  :license "MIT"
  :version "0.0.1"
  :serial t
  :depends-on (#:cffi #:bordeaux-threads #:alexandria)
  :components ((:module "wgsl"
                :components
                ((:file "package")
                 (:file "ir")
                 (:file "walker")
                 (:file "types")
                 (:file "infer")
                 (:file "shader-base")
                 (:file "cl-functions")
                 (:file "builtins")
                 (:file "finalize-inference")
                 (:file "print-base")
                 (:file "wgsl-printer")
                 (:file "compiler")
                 (:file "api")))))

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
