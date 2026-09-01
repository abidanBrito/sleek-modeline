;;; sleek-modeline-modal.el --- Modal editing segment for sleek-modeline -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Abidán Brito Clavijo
;; Author: Abidán Brito Clavijo <abidan.brito@gmail.com>
;; SPDX-License-Identifier: MIT

;;; Commentary:
;; Modal editing segment for the `sleek-modeline' package.  Displays a
;; single-letter marker for the current modal editing state, supporting
;; both `evil-mode' and `meow-mode'.

;;; Code:

(require 'sleek-modeline-core)

(defcustom sleek-modeline-show-modal-state nil
  "Whether to show modal editing state (Evil/Meow) marker."
  :type 'boolean
  :group 'sleek-modeline)

(defcustom sleek-modeline-hide-modal-inactive nil
  "Hide modal state marker in inactive modelines."
  :type 'boolean
  :group 'sleek-modeline)

(defface sleek-modeline-modal-normal-face
  '((t (:weight bold :foreground "#1e1e2e" :background "#89b4fa")))
  "Face for normal modal state." :group 'sleek-modeline-faces)

(defface sleek-modeline-modal-insert-face
  '((t (:weight bold :foreground "#1e1e2e" :background "#a6e3a1")))
  "Face for insert modal state." :group 'sleek-modeline-faces)

(defface sleek-modeline-modal-visual-face
  '((t (:weight bold :foreground "#1e1e2e" :background "#cba6f7")))
  "Face for visual modal state." :group 'sleek-modeline-faces)

(defface sleek-modeline-modal-other-face
  '((t (:weight bold :foreground "#1e1e2e" :background "#f38ba8")))
  "Face for other modal states." :group 'sleek-modeline-faces)

(defun sleek-modeline--modal-state ()
  "Return the current modal editing state as a single letter, or nil.
Checks `evil-mode' first, then `meow-mode'.  Returns nil if neither is active."
  (when sleek-modeline-show-modal-state
    (cond
     ((and (featurep 'evil)
           (bound-and-true-p evil-local-mode)
           (boundp 'evil-state))
      (pcase evil-state
        ('normal "N")
        ('insert "I")
        ('visual "V")
        ('replace "R")
        ('operator "O")
        ('motion "M")
        ('emacs "E")
        (_ "?")))
     ((and (featurep 'meow)
           (bound-and-true-p meow-mode)
           (boundp 'meow--current-state))
      (pcase meow--current-state
        ('normal "N")
        ('insert "I")
        ('keypad "K")
        ('motion "M")
        ('beacon "B")
        (_ "?")))
     (t nil))))

(defun sleek-modeline-modal-state-marker ()
  "Return a propertized, modal state marker with state-dependent background.
In inactive mode-lines, dim the badge background (keeping the foreground),
or hide it entirely when `sleek-modeline-hide-modal-inactive' is non-nil."
  (when-let* ((state (sleek-modeline--modal-state)))
    (let ((inactive (sleek-modeline--inactive-p)))
      (unless (and inactive sleek-modeline-hide-modal-inactive)
        (let* ((base-face (pcase state
                            ("N" 'sleek-modeline-modal-normal-face)
                            ("I" 'sleek-modeline-modal-insert-face)
                            ("V" 'sleek-modeline-modal-visual-face)
                            (_   'sleek-modeline-modal-other-face)))
               (face (if inactive
                         (list :inherit base-face
                               :background (face-foreground
                                            'mode-line-inactive nil t))
                       base-face)))
          (propertize (format " %s " state) 'face face))))))

(sleek-modeline-register-segment 'modal-state
				 :fn 'sleek-modeline-modal-state-marker
				 :side 'left
				 :priority 0
				 :separator " ")

(provide 'sleek-modeline-modal)
;;; sleek-modeline-modal.el ends here
