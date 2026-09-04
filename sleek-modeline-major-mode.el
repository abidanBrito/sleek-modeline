;;; sleek-modeline-major-mode.el --- Major mode segment for sleek-modeline -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Abidán Brito Clavijo
;; Author: Abidán Brito Clavijo <abidan.brito@gmail.com>
;; SPDX-License-Identifier: MIT

;;; Commentary:
;; Major mode segment for the `sleek-modeline' package.  Displays the
;; current major mode name; clicking it pops up a menu of the active
;; minor modes.

;;; Code:

(require 'sleek-modeline-core)

;; Tell the byte-compiler this is a dynamic variable from delight.
(defvar delight-mode-name-inhibit)

(defvar sleek-modeline--major-mode-keymap
  (let ((map (make-sparse-keymap)))
    (define-key map [mode-line down-mouse-1] #'sleek-modeline--minor-modes-menu)
    map)
  "Keymap active on the major mode segment of `sleek-modeline'.")

(defcustom sleek-modeline-hide-major-mode-inactive nil
  "Hide the major mode name in inactive modelines."
  :type 'boolean
  :group 'sleek-modeline)

(defcustom sleek-modeline-use-delight-for-major-mode nil
  "When non-nil, use `delight's substituted name for the major mode.
When nil (the default), show the raw major mode name, bypassing any
`delight' customisation."
  :type 'boolean
  :group 'sleek-modeline)

(defface sleek-modeline-major-mode-face
  '((t (:inherit font-lock-function-name-face :weight bold :slant normal)))
  "Face for major mode in `sleek-modeline'."
  :group 'sleek-modeline-faces)

(defface sleek-modeline-major-mode-highlight-face
  '((t (:inherit sleek-modeline-major-mode-face :underline t)))
  "Face used to highlight the major mode segment on mouse hover."
  :group 'sleek-modeline-faces)

(defun sleek-modeline--active-minor-modes ()
  "Return the list of active minor modes in the current buffer."
  (let (modes)
    (dolist (mode minor-mode-list)
      (when (and (boundp mode) (symbol-value mode))
        (push mode modes)))
    (nreverse modes)))

(defun sleek-modeline--minor-modes-menu (event)
  "Pop up a menu of the active minor modes at the mouse EVENT.
Selecting an entry describes that minor mode."
  (interactive "@e")
  (let ((modes (sleek-modeline--active-minor-modes))
        (map (make-sparse-keymap "Active minor modes")))
    (if (null modes)
        (message "No active minor modes")
      ;; NOTE(abi): `define-key' prepends, so we walk the list in reverse.
      (dolist (mode (reverse modes))
        (define-key map (vector mode)
		    `(menu-item ,(symbol-name mode)
				(lambda ()
				  (interactive)
				  (describe-minor-mode-from-symbol ',mode)))))
      (popup-menu map event))))

(defun sleek-modeline-major-mode ()
  "Show major mode with custom face, stripping mode-line suffix indicators.
Clicking the segment pops up a menu of the active minor modes.
Optionally dim or hide in inactive mode-lines."
  (let* ((raw (if sleek-modeline-use-delight-for-major-mode
                  ;; Bind to nil to allow delight's substituted name through
                  (let ((delight-mode-name-inhibit nil))
                    (format-mode-line mode-name))
                ;; Default: just call format-mode-line normally (delight suppressed by its own advice)
                (format-mode-line mode-name)))
         (name (replace-regexp-in-string
                "/.*\\'" ""
                (substring-no-properties raw))))
    (sleek-modeline--maybe-dim-or-hide
     (propertize name
                 'face 'sleek-modeline-major-mode-face
                 'mouse-face 'sleek-modeline-major-mode-highlight-face
                 'help-echo (concat (propertize "mouse-1" 'face
                                                'sleek-modeline-major-mode-face)
                                    ": list active minor modes")
                 'local-map sleek-modeline--major-mode-keymap)
     sleek-modeline-hide-major-mode-inactive)))

(sleek-modeline-register-segment 'major-mode
				 :fn 'sleek-modeline-major-mode
				 :side 'right
				 :priority 40)

(provide 'sleek-modeline-major-mode)
;;; sleek-modeline-major-mode.el ends here
