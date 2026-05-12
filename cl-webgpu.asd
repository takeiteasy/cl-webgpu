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
                ((:file "package")
                 (:file "library")
                 (:file "types")
                 (:file "functions")))))

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
