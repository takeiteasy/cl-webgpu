;;;; tests/wrapper-tests.lisp
;;;;
;;;; Smoke tests for cl-webgpu/wrapper against a real GPU adapter (via
;;;; cl-webgpu/headless -- no window, no display server). These aren't
;;;; correctness tests of wgpu-native itself; they exist to catch API-shape
;;;; regressions in the wrapper layer: the Lisp-vector WRITE-BUFFER path,
;;;; MAKE-BUFFER-WITH-DATA, and the raw-pointer -> CLOS handle change for
;;;; samplers/bind-groups/bind-group-layouts.

(in-package #:cl-webgpu/wrapper/tests)

(in-suite wrapper-tests)

(defmacro with-test-device ((device queue) &body body)
  "Bind DEVICE and QUEUE to a real headless GPU device/queue for the extent
of BODY, releasing everything on exit."
  `(cl-webgpu/wrapper:with-gpu* ((inst    (cl-webgpu/wrapper:make-gpu-instance))
                                 (adapter (cl-webgpu/wrapper:request-gpu-adapter inst))
                                 (,device (cl-webgpu/wrapper:request-gpu-device inst adapter))
                                 (,queue  (cl-webgpu/wrapper:get-device-queue ,device)))
     ,@body))

(test make-buffer-with-data-and-write-buffer-vectors
  "MAKE-BUFFER-WITH-DATA and WRITE-BUFFER accept Lisp vectors directly (no
caller-side foreign-alloc/copy/free), for all three supported element types."
  (with-test-device (device queue)
    (let* ((floats (make-array 4 :element-type 'single-float
                                  :initial-contents '(1.0 2.0 3.0 4.0)))
           (u32s   (make-array 3 :element-type '(unsigned-byte 32)
                                  :initial-contents '(10 20 30)))
           ;; WebGPU requires WRITE-BUFFER's byte count be a multiple of
           ;; COPY_BUFFER_ALIGNMENT (4) -- 4 bytes here, not an arbitrary length.
           (bytes  (make-array 4 :element-type '(unsigned-byte 8)
                                  :initial-contents '(1 2 3 4)))
           (buf1   (cl-webgpu/wrapper:make-buffer-with-data
                    device queue floats
                    (logior cl-webgpu:+wgpu-buffer-usage-uniform+
                            cl-webgpu:+wgpu-buffer-usage-copy-dst+)))
           (buf2   (cl-webgpu/wrapper:make-buffer
                    device :size 16
                    :usage (logior cl-webgpu:+wgpu-buffer-usage-storage+
                                   cl-webgpu:+wgpu-buffer-usage-copy-dst+))))
      (is (typep buf1 'cl-webgpu/wrapper:gpu-buffer))
      ;; Re-upload via WRITE-BUFFER with each vector type; none of these
      ;; should signal (the etypecase dispatch + scratch-buffer path).
      (finishes (cl-webgpu/wrapper:write-buffer queue buf1 0 floats))
      (finishes (cl-webgpu/wrapper:write-buffer queue buf2 0 u32s))
      (finishes (cl-webgpu/wrapper:write-buffer queue buf2 0 bytes))
      (cl-webgpu/wrapper:release buf1)
      (cl-webgpu/wrapper:release buf2))))

(test sampler-is-a-releasable-gpu-handle
  "MAKE-SAMPLER returns a GPU-SAMPLER (not a raw pointer), releasable via RELEASE."
  (with-test-device (device queue)
    (let ((sampler (cl-webgpu/wrapper:make-sampler device)))
      (is (typep sampler 'cl-webgpu/wrapper:gpu-sampler))
      (finishes (cl-webgpu/wrapper:release sampler)))))

(test bind-group-round-trip
  "GET-PIPELINE-BIND-GROUP-LAYOUT and MAKE-BIND-GROUP return releasable CLOS
handles, and SET-BIND-GROUP accepts the wrapped GPU-BIND-GROUP directly --
the exact round trip weasel's %create-uniform-bind-group needs."
  (with-test-device (device queue)
    (let* ((vs "@vertex fn vs_main(@builtin(vertex_index) i: u32) -> @builtin(position) vec4<f32> { return vec4<f32>(0.0, 0.0, 0.0, 1.0); }")
           (fs "@group(0) @binding(0) var<uniform> u: vec4<f32>;
@fragment fn fs_main() -> @location(0) vec4<f32> { return u; }"))
      (cl-webgpu/wrapper:with-gpu* ((vmod (cl-webgpu/wrapper:make-shader-module device vs))
                                    (fmod (cl-webgpu/wrapper:make-shader-module device fs))
                                    (pipeline (cl-webgpu/wrapper:make-render-pipeline
                                               device :vertex-module vmod :fragment-module fmod
                                               :vertex-entry-point "vs_main"
                                               :fragment-entry-point "fs_main"))
                                    (ubuf (cl-webgpu/wrapper:make-buffer-with-data
                                           device queue
                                           (make-array 4 :element-type 'single-float :initial-element 0.0)
                                           (logior cl-webgpu:+wgpu-buffer-usage-uniform+
                                                   cl-webgpu:+wgpu-buffer-usage-copy-dst+))))
        (cl-webgpu/wrapper:with-gpu* ((layout (cl-webgpu/wrapper:get-pipeline-bind-group-layout pipeline 0)))
          (is (typep layout 'cl-webgpu/wrapper:gpu-bind-group-layout))
          (cl-webgpu/wrapper:with-gpu* ((bg (cl-webgpu/wrapper:make-bind-group
                                             device layout
                                             (list (list :binding 0 :buffer ubuf :size 16)))))
            (is (typep bg 'cl-webgpu/wrapper:gpu-bind-group))))))))

(test surface-texture-status-decode-handles-native-extension-values
  "%DECODE-SURFACE-TEXTURE-STATUS must not error on wgpu-native's Occluded
extension status (#x30001, outside the base WGPUSurfaceGetCurrentTextureStatus
enum) or on any other unrecognized raw value -- GET-CURRENT-SURFACE-TEXTURE
used to crash here via CFFI's strict enum decode (seen live: a backgrounded
window on macOS returns this status every frame)."
  (is (eq :occluded (cl-webgpu/wrapper::%decode-surface-texture-status #x30001)))
  (is (eq :success-optimal (cl-webgpu/wrapper::%decode-surface-texture-status #x1)))
  (is (eq :unknown (cl-webgpu/wrapper::%decode-surface-texture-status #xdeadbeef))))

(test write-texture-accepts-lisp-byte-vector
  "WRITE-TEXTURE accepts a (simple-array (unsigned-byte 8) (*)) directly, not
just a foreign pointer -- the pixel-upload path weasel's texture uniforms need."
  (with-test-device (device queue)
    (cl-webgpu/wrapper:with-gpu* (((tex view) (cl-webgpu/wrapper:make-texture-2d device 2 2)))
      (is (typep view 'cl-webgpu/wrapper:gpu-texture-view))
      (let ((pixels (make-array 16 :element-type '(unsigned-byte 8) :initial-element 255)))
        (finishes (cl-webgpu/wrapper:write-texture queue tex pixels 16
                                                    :width 2 :height 2 :bytes-per-row 8))))))

(test with-gpu*-multi-value-binding-releases-both
  "WITH-GPU* supports ((var1 var2) form) bindings for multi-value returns
like MAKE-TEXTURE-2D, releasing both on exit."
  (with-test-device (device queue)
    (finishes
      (cl-webgpu/wrapper:with-gpu* (((tex view) (cl-webgpu/wrapper:make-texture-2d device 4 4)))
        (is (typep tex 'cl-webgpu/wrapper:gpu-texture))
        (is (typep view 'cl-webgpu/wrapper:gpu-texture-view))))))
