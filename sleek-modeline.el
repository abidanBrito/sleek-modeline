;;; sleek-modeline.el --- Minimal and elegant modeline -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Abidán Brito Clavijo

;; Author: Abidán Brito Clavijo <abidan.brito@gmail.com>
;; Version: 1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: mode-line, faces
;; URL: https://github.com/abidanBrito/sleek-modeline
;; SPDX-License-Identifier: MIT

;;; Commentary:

;; This package provides a minimal and elegant modeline replacement.

;;; Code:

(require 'sleek-modeline-core)
(require 'sleek-modeline-buffer)
(require 'sleek-modeline-major-mode)
(require 'sleek-modeline-modal)
(require 'sleek-modeline-line-ending)
(require 'sleek-modeline-vc)


(defcustom sleek-modeline-enable-diagnostics t
  "Enable diagnostics segment integration in sleek-modeline."
  :type 'boolean
  :group 'sleek-modeline)

(defcustom sleek-modeline-enable-project t
  "Enable project name segment integration in sleek-modeline.
Supports `projectile' and the built-in `project.el', preferring
projectile when both are active."
  :type 'boolean
  :group 'sleek-modeline)

(defcustom sleek-modeline-enable-lsp t
  "Enable LSP segment integration in sleek-modeline.
Supports `eglot' and `lsp-mode' backends."
  :type 'boolean
  :group 'sleek-modeline)

(defcustom sleek-modeline-edge-padding 2
  "Number of spaces at the left and right edges of the mode-line."
  :type 'integer
  :group 'sleek-modeline)

(defcustom sleek-modeline-suppress-default-mouse t
  "Whether to suppress Emacs' default mode-line mouse behavior.
When non-nil, the stock mouse actions on bare mode-line areas
and their echo area hints are disabled.  Only the mouse events
explicitly assigned by `sleek-modeline' segments remain active."
  :type 'boolean
  :group 'sleek-modeline)

(defvar sleek-modeline--saved-modeline-attrs nil
  "Saved `mode-line' face attributes before sleek-modeline modified them.")

(defvar sleek-modeline--saved-modeline-inactive-attrs nil
  "Saved `mode-line-inactive' face attributes before sleek-modeline modified them.")

(defvar sleek-modeline--default-mouse-events
  '([mode-line mouse-1]
    [mode-line mouse-2]
    [mode-line mouse-3])
  "Mode-line mouse events whose default global bindings are suppressed.
Deliberately excludes `down-mouse-1', which is bound to
`mouse-drag-mode-line' and is what lets the user resize a window by
dragging its mode-line (the divider between stacked windows).
Suppressing it would break drag-to-resize.")

(defvar sleek-modeline--saved-mouse-bindings nil
  "Alist of (EVENT . BINDING) saved before suppressing default mouse events.")

(defvar sleek-modeline--saved-default-help-echo 'unset
  "Storage for the value of variable `mode-line-default-help-echo'.")

(defvar sleek-modeline-format nil
  "The sleek mode-line format.  Built by `sleek-modeline--build-format'.")

(defvar sleek-modeline--default-mode-line mode-line-format
  "Storage for the default `mode-line-format'.")

(defun sleek-modeline--segment-eval-form (seg)
  "Return an (:eval ...) mode-line form for segment SEG."
  (let* ((fn (plist-get seg :fn))
         (sep (plist-get seg :separator))
         (cond-var (plist-get seg :condition))
         (core (if sep
                   (let ((suffix (if (eq sep t)
                                     '(sleek-modeline--separator)
                                   sep)))
                     `(when-let ((result (,fn)))
                        (concat result ,suffix)))
                 `(,fn)))
         (form (if cond-var `(when ,cond-var ,core) core)))
    `(:eval (unless (sleek-modeline--hide-inactive-p) ,form))))

(defun sleek-modeline--build-format ()
  "Rebuild `sleek-modeline-format' from the segment registry."
  (let* ((by-priority (lambda (a b)
                        (< (plist-get a :priority) (plist-get b :priority))))
         (left  (sort (seq-filter (lambda (s) (eq (plist-get s :side) 'left))
                                  sleek-modeline--segment-registry)
                      by-priority))
         (right (sort (seq-filter (lambda (s) (eq (plist-get s :side) 'right))
                                  sleek-modeline--segment-registry)
                      by-priority)))
    (setq sleek-modeline-format
          `("%e"
            (:eval (unless (sleek-modeline--hide-inactive-p)
                     (make-string sleek-modeline-edge-padding ?\s)))
            ,@(mapcar #'sleek-modeline--segment-eval-form left)
            mode-line-format-right-align
            ,@(mapcar #'sleek-modeline--segment-eval-form right)
            (:eval (unless (sleek-modeline--hide-inactive-p)
                     (make-string sleek-modeline-edge-padding ?\s)))))))

(defun sleek-modeline--suppress-default-mouse ()
  "Disable Emacs' default mode-line mouse actions and echo area hints.
Saves the prior global bindings and variable `mode-line-default-help-echo'
so that they can be restored by `sleek-modeline--restore-default-mouse'."
  (setq sleek-modeline--saved-mouse-bindings
        (mapcar (lambda (event)
                  (cons event (lookup-key global-map event)))
                sleek-modeline--default-mouse-events))
  (dolist (event sleek-modeline--default-mouse-events)
    (define-key global-map event #'ignore))
  (setq sleek-modeline--saved-default-help-echo mode-line-default-help-echo)
  (setq mode-line-default-help-echo nil))

(defun sleek-modeline--restore-default-mouse ()
  "Restore the default mode-line mouse bindings and echo area hints."
  (dolist (entry sleek-modeline--saved-mouse-bindings)
    (define-key global-map (car entry) (cdr entry)))
  (setq sleek-modeline--saved-mouse-bindings nil)
  (unless (eq sleek-modeline--saved-default-help-echo 'unset)
    (setq mode-line-default-help-echo sleek-modeline--saved-default-help-echo)
    (setq sleek-modeline--saved-default-help-echo 'unset)))

(defun sleek-modeline--after-theme-change (&rest _)
  "Update faces after theme change."
  (run-with-timer 0.1 nil #'sleek-modeline--update-faces))

(defun sleek-modeline--real-frame-p (frame)
  "Return non-nil when FRAME is a real (non-daemon-initial) frame.
The daemon creates an invisible stub frame associated with the special
terminal named \"initial_terminal\".  That frame reports `framep' as t
and `frame-visible-p' as t, so those predicates cannot distinguish it
from a real TTY frame.  We match its terminal name directly, matching
the approach used inside Emacs' own `debug.el'.  Nil FRAME means the
selected frame."
  (let ((f (or frame (selected-frame))))
    (and (frame-live-p f)
         (not (string-equal (terminal-name (frame-terminal f))
                            "initial_terminal")))))

(defun sleek-modeline--graphical-frame-exists-p ()
  "Return non-nil when at least one real client frame exists.
A \"real\" frame is either graphical or a TTY, excluding the daemon's
initial invisible stub."
  (and (not noninteractive)
       (cl-some #'sleek-modeline--real-frame-p (frame-list))))

(defun sleek-modeline--deferred-face-update (&optional frame)
  "Recompute mode-line faces once a real client frame is available.
Designed to be hung on `server-after-make-frame-hook' and
`after-make-frame-functions'.  Runs a single face update in the
context of FRAME (or the selected frame) on an idle timer so that
face realisation on the new frame has a chance to complete before
we read `(face-background \='default ...)'."
  (when (and (bound-and-true-p sleek-modeline-mode)
             (sleek-modeline--real-frame-p frame))
    (remove-hook 'server-after-make-frame-hook
                 #'sleek-modeline--deferred-face-update)
    (remove-hook 'after-make-frame-functions
                 #'sleek-modeline--deferred-face-update)

    ;; NOTE(abi): defer to the next idle moment so the new frame is fully
    ;;            realised (theme applied, `default' background set).  Otherwise
    ;;            `face-background' may still return the daemon initial frame's
    ;;            pre-theme colour.
    (let ((target-frame (or frame (selected-frame))))
      (run-with-idle-timer
       0 nil
       (lambda ()
         (when (frame-live-p target-frame)
           (with-selected-frame target-frame
             (sleek-modeline--update-faces))))))))

;;;###autoload
(define-minor-mode sleek-modeline-mode
  "Toggle sleek modeline on and off."
  :global t
  :group 'sleek-modeline
  (if sleek-modeline-mode
      (progn
	;; Load optional modules so they self-register before building the format
        (when sleek-modeline-enable-diagnostics
          (require 'sleek-modeline-diagnostics nil t))
        (when sleek-modeline-enable-project
          (require 'sleek-modeline-project nil t))
        (when sleek-modeline-enable-lsp
          (require 'sleek-modeline-lsp nil t))

	;; Build the format from the segment registry
        (sleek-modeline--build-format)

	;; Save original format & face attributes
	(unless (equal (default-value 'mode-line-format) sleek-modeline-format)
	  (setq sleek-modeline--default-mode-line
		(default-value 'mode-line-format))
          (setq sleek-modeline--saved-modeline-attrs
		(list :background (face-attribute 'mode-line :background nil t)
                      :box (face-attribute 'mode-line :box nil t)
                      :underline (face-attribute 'mode-line :underline nil t)
                      :overline (face-attribute 'mode-line :overline nil t)))
          (setq sleek-modeline--saved-modeline-inactive-attrs
		(list :background (face-attribute 'mode-line-inactive :background nil t)
                      :box (face-attribute 'mode-line-inactive :box nil t)
                      :underline (face-attribute 'mode-line-inactive :underline nil t)
                      :overline (face-attribute 'mode-line-inactive :overline nil t))))

	;; Apply `sleek-modeline' format
        (setq-default mode-line-format sleek-modeline-format)

	;; Suppress Emacs' default mode-line mouse actions
	(when sleek-modeline-suppress-default-mouse
	  (sleek-modeline--suppress-default-mouse))

	;; Update faces after a theme change
        (add-hook 'after-load-theme-hook #'sleek-modeline--update-faces)
        (advice-add 'load-theme :after #'sleek-modeline--after-theme-change)
        (advice-add 'enable-theme :after #'sleek-modeline--after-theme-change)

	;; Activate registered segments
        (dolist (seg sleek-modeline--segment-registry)
          (let ((condition (plist-get seg :condition))
                (on-enable (plist-get seg :on-enable)))
            (when (and on-enable
                       (or (null condition) (symbol-value condition)))
              (funcall on-enable))))

	;; Update faces now if a real (non-daemon-initial) frame exists,
	;; otherwise defer the first update until a client frame shows up
	;;
	;; IMPORTANT(abi): this fixes a daemon-startup colour bug where faces were
	;;                 computed against the initial frame's unthemed `default'
	;;                 background, leaving the wrong face until a server restart.
	(if (sleek-modeline--graphical-frame-exists-p)
	    (sleek-modeline--update-faces)
	  (add-hook 'server-after-make-frame-hook
		    #'sleek-modeline--deferred-face-update)
	  (add-hook 'after-make-frame-functions
		    #'sleek-modeline--deferred-face-update)))

    ;; Restore original format, faces & mouse behaviour
    (setq-default mode-line-format sleek-modeline--default-mode-line)

    (sleek-modeline--restore-default-mouse)

    (when sleek-modeline--saved-modeline-attrs
      (apply #'set-face-attribute 'mode-line nil
             sleek-modeline--saved-modeline-attrs))

    (when sleek-modeline--saved-modeline-inactive-attrs
      (apply #'set-face-attribute 'mode-line-inactive nil
             sleek-modeline--saved-modeline-inactive-attrs))

    ;; Remove hooks and advices added by sleek-modeline
    (remove-hook 'after-load-theme-hook #'sleek-modeline--update-faces)
    (remove-hook 'server-after-make-frame-hook
                 #'sleek-modeline--deferred-face-update)
    (remove-hook 'after-make-frame-functions
                 #'sleek-modeline--deferred-face-update)

    (advice-remove 'load-theme #'sleek-modeline--after-theme-change)
    (advice-remove 'enable-theme #'sleek-modeline--after-theme-change)

    ;; Deactivate registered segments
    (dolist (seg sleek-modeline--segment-registry)
      (let ((condition (plist-get seg :condition))
            (on-disable (plist-get seg :on-disable)))
        (when (and on-disable
                   (or (null condition) (symbol-value condition)))
          (funcall on-disable)))))

  (force-mode-line-update t))

(provide 'sleek-modeline)
;;; sleek-modeline.el ends here
