(in-package #:cl-webgpu/shader/internal)

;; define builtin variables for supported shader stages
;; (vertex, fragment, compute)
;; Uses WGSL-native names only.

(let ((cl-webgpu/shader::*environment* *shader-base-environment*)
      (cl-webgpu/shader::*global-environment* *shader-base-environment*)
      (walker (make-instance 'shader-walker)))
  (macrolet ((input (name type stage &rest qualifiers)
               (declare (ignorable qualifiers))
               `(cl-webgpu/shader::walk '(input ,name ,type :stage ,stage
                                      :internal t)
                                    walker))
             (const (name type stage &rest qualifiers)
               (declare (ignorable qualifiers))
               `(cl-webgpu/shader::walk '(input ,name ,type :stage ,stage
                                      :internal t)
                                    walker))
             (output (name type stage  &rest qualifiers)
               (declare (ignorable qualifiers))
               `(cl-webgpu/shader::walk '(output ,name ,type :stage ,stage
                                      :internal t)
                                    walker)))

    ;; compute
    (input (num-workgroups "num_workgroups") :uvec3 :compute)
    (input (workgroup-id "workgroup_id") :uvec3 :compute)
    (input (local-invocation-id "local_invocation_id") :uvec3 :compute)
    (input (global-invocation-id "global_invocation_id") :uvec3 :compute)
    (input (local-invocation-index "local_invocation_index") :uint :compute)

    ;; vertex
    (input (vertex-index "vertex_index") :uint :vertex)
    (input (instance-index "instance_index") :uint :vertex)

    ;; fragment
    (input (frag-position "position") :vec4 :fragment)
    (input (front-facing "front_facing") :bool :fragment)
    (input (sample-index "sample_index") :uint :fragment)
    (input (sample-mask "sample_mask") (:int *) :fragment)
    (output (frag-depth "frag_depth") :float :fragment)
    (output (sample-mask-out "sample_mask") (:int *) :fragment)))
