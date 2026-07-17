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

(asdf:defsystem #:cl-webgpu/wrapper
  :description "CLOS wrapper layer for cl-webgpu"
  :author "George Watson <gigolo@hotmail.co.uk>"
  :license "MIT"
  :version "0.0.1"
  :serial t
  :depends-on (#:cl-webgpu)
  :components ((:module "wrapper"
                :components
                ((:file "package")
                 (:file "wrapper")))))

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

(asdf:defsystem #:cl-webgpu/glfw-dummy
  :description "Headless drop-in replacement for cl-webgpu/glfw's window/loop calls, for SSH/CI testing"
  :author "George Watson <gigolo@hotmail.co.uk>"
  :license "MIT"
  :version "0.0.1"
  :serial t
  :depends-on (#:cffi)
  :components ((:module "glfw-dummy"
                :components
                ((:file "package")
                 (:file "glfw-dummy")))))

(asdf:defsystem #:cl-webgpu/headless
  :description "Offscreen render target + PNG readback for headless testing"
  :author "George Watson <gigolo@hotmail.co.uk>"
  :license "MIT"
  :version "0.0.1"
  :serial t
  :depends-on (#:cl-webgpu/wrapper #:zpng)
  :components ((:module "headless"
                :components
                ((:file "package")
                 (:file "headless")))))

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

(asdf:defsystem #:cl-webgpu/shader/tests
  :description "Tests for cl-webgpu/shader (the WGSL DSL)"
  :author "George Watson <gigolo@hotmail.co.uk>"
  :license "MIT"
  :version "0.0.1"
  :depends-on (#:cl-webgpu/shader #:fiveam)
  :pathname "tests/"
  :serial t
  :components ((:file "package")
               (:file "fixtures")
               (:file "wgsl-tests"))
  :perform (test-op (op c)
             (unless (uiop:symbol-call :cl-webgpu/shader/tests :run-tests)
               (error "cl-webgpu/shader/tests: one or more tests failed"))))

(asdf:defsystem #:cl-webgpu/nuklear
  :description "Nuklear immediate-mode GUI integration for cl-webgpu"
  :author "George Watson <gigolo@hotmail.co.uk>"
  :license "MIT"
  :version "0.0.1"
  :serial t
  :depends-on (#:cl-webgpu #:cl-webgpu/wrapper #:cl-nuklear)
  :components ((:module "nuklear"
                :components
                ((:file "package")
                 (:file "backend")))))

(asdf:defsystem #:cl-webgpu/nuklear-glfw-glue
  :description "GLFW input wiring for cl-webgpu/nuklear (mouse/keyboard/scroll)"
  :author "George Watson <gigolo@hotmail.co.uk>"
  :license "MIT"
  :version "0.0.1"
  :serial t
  :depends-on (#:cl-webgpu/nuklear #:cl-webgpu/glfw)
  :components ((:module "nuklear"
                :components
                ((:file "glfw-input")))))

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
