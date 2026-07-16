;;;; glfw-dummy/glfw-dummy.lisp
;;;;
;;;; Drop-in stand-in for the subset of cl-glfw3 (or cl-webgpu/glfw) calls a
;;;; typical WebGPU app loop uses: INITIALIZE, CREATE-WINDOW,
;;;; WINDOW-SHOULD-CLOSE-P, POLL-EVENTS, DESTROY-WINDOW, TERMINATE,
;;;; GET-PRIMARY-MONITOR. Opens no real window and touches no display server
;;;; or macOS screen-recording permission -- it exists purely to make an
;;;; app's existing "loop until window-should-close-p" render loop terminate
;;;; on its own after a fixed number of frames, so the loop can drive a
;;;; GPU-OFFSCREEN-TARGET (see cl-webgpu/headless) instead of a real surface.
;;;;
;;;; Swap the package an app's window/loop calls are qualified with (or the
;;;; :depends-on'd GLFW system) to switch between real and headless mode;
;;;; the render loop itself does not need to change.

(in-package #:cl-webgpu/glfw-dummy)

(defvar *frame-budget* 1
  "Number of POLL-EVENTS calls before WINDOW-SHOULD-CLOSE-P starts returning
T. Rebind before CREATE-WINDOW to control how many frames a headless run
renders before its loop exits on its own.")

(defstruct dummy-window
  (frame-count 0))

(defvar *window* nil)

(defun initialize ()
  t)

(defun terminate ()
  (setf *window* nil)
  t)

(defun get-primary-monitor ()
  (cffi:null-pointer))

(defun create-window (&rest keys)
  (declare (ignore keys))
  (setf *window* (make-dummy-window)))

(defun destroy-window (&optional (window *window*))
  (declare (ignore window))
  (setf *window* nil))

(defun window-should-close-p (&optional (window *window*))
  (>= (dummy-window-frame-count window) *frame-budget*))

(defun poll-events ()
  (when *window*
    (incf (dummy-window-frame-count *window*)))
  nil)
