;;; sleek-modeline-line-ending.el --- Line ending segment for sleek-modeline -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Abidán Brito Clavijo
;; Author: Abidán Brito Clavijo <abidan.brito@gmail.com>
;; SPDX-License-Identifier: MIT

;;; Commentary:
;; Line ending segment for the `sleek-modeline' package.  Displays the
;; buffer's line ending convention (LF/CRLF/CR) for file-backed buffers.

;;; Code:

(require 'sleek-modeline-core)

(defvar sleek-modeline-line-ending--keymap
  (let ((map (make-sparse-keymap)))
    (define-key map [mode-line mouse-1] #'sleek-modeline-line-ending--toggle)
    map)
  "Keymap active on the line ending segment of `sleek-modeline'.")

(defcustom sleek-modeline-hide-line-ending-inactive nil
  "Hide the line ending style in inactive modelines."
  :type 'boolean
  :group 'sleek-modeline)

(defface sleek-modeline-line-ending-face
  '((t (:inherit font-lock-doc-face :slant normal)))
  "Face for the line ending indicator in `sleek-modeline'."
  :group 'sleek-modeline-faces)

(defface sleek-modeline-line-ending-highlight-face
  '((t (:inherit sleek-modeline-line-ending-face :underline t)))
  "Face used to highlight the line ending segment on mouse hover."
  :group 'sleek-modeline-faces)

(defun sleek-modeline-line-ending--toggle ()
  "Toggle line endings between LF and CRLF for the clicked buffer."
  (interactive "@")
  (set-buffer-file-coding-system
   (coding-system-change-eol-conversion
    buffer-file-coding-system
    (if (eq (coding-system-eol-type buffer-file-coding-system) 0)
        'dos
      'unix))))

(defun sleek-modeline--line-ending ()
  "Return (SHORT . LONG) descriptions of the buffer's line ending convention.
SHORT is the compact segment label; LONG is the literal for the hover tooltip."
  (pcase (coding-system-eol-type buffer-file-coding-system)
    (0 '("LF"   . "Unix (LF)"))
    (1 '("CRLF" . "DOS (CRLF)"))
    (2 '("CR"   . "Mac (CR)"))
    (_ '("-"    . "unknown"))))

(defun sleek-modeline-line-ending-indicator ()
  "Return a propertized line ending string for file-backed buffers, or nil.
Dim or hide in inactive mode-lines according to configuration."
  (when buffer-file-name
    (let ((style (sleek-modeline--line-ending)))
      (sleek-modeline--maybe-dim-or-hide
       (propertize (car style)
                   'face 'sleek-modeline-line-ending-face
                   'mouse-face 'sleek-modeline-line-ending-highlight-face
                   'help-echo (concat "Line endings: " (cdr style))
                   'local-map sleek-modeline-line-ending--keymap)
       sleek-modeline-hide-line-ending-inactive))))

(sleek-modeline-register-segment 'line-ending
                                 :fn 'sleek-modeline-line-ending-indicator
                                 :side 'right
                                 :priority 10
                                 :separator t)

(provide 'sleek-modeline-line-ending)
;;; sleek-modeline-line-ending.el ends here
