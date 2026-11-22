;;; sleek-modeline-buffer.el --- Buffer name segment for sleek-modeline -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Abidán Brito Clavijo
;; Author: Abidán Brito Clavijo <abidan.brito@gmail.com>
;; SPDX-License-Identifier: MIT

;;; Commentary:
;; Buffer name segment for the `sleek-modeline' package.  Displays the
;; current buffer name with an optional file icon, highlighting it when
;; the buffer has unsaved changes.

;;; Code:

(require 'sleek-modeline-core)

;; NOTE(abi): optional dependency; only gets loaded if available.
(declare-function nerd-icons-icon-for-file "ext:nerd-icons")

(defcustom sleek-modeline-highlight-modified-buffer-name t
  "Whether to highlight the buffer name when it has unsaved changes.
When non-nil, modified buffers will use
`sleek-modeline-buffer-name-modified-face'."
  :type 'boolean
  :group 'sleek-modeline)

(defcustom sleek-modeline-hide-file-icon-inactive nil
  "Hide the file icon in inactive modelines."
  :type 'boolean
  :group 'sleek-modeline)

(defface sleek-modeline-buffer-name-face
  '((t (:inherit mode-line-buffer-id :weight bold)))
  "Face for buffer name in `sleek-modeline'."
  :group 'sleek-modeline-faces)

(defface sleek-modeline-buffer-name-highlight-face
  '((t (:inherit sleek-modeline-buffer-name-face :underline t)))
  "Face used to highlight the buffer name segment on mouse hover."
  :group 'sleek-modeline-faces)

(defface sleek-modeline-buffer-name-modified-face
  '((t (:inherit warning :weight bold)))
  "Face for modified buffer name in `sleek-modeline'."
  :group 'sleek-modeline-faces)

(defface sleek-modeline-buffer-name-modified-highlight-face
  '((t (:inherit sleek-modeline-buffer-name-modified-face :underline t)))
  "Face used to highlight a modified buffer name on mouse hover."
  :group 'sleek-modeline-faces)

(defun sleek-modeline-buffer-name ()
  "Show buffer name with custom face and optional icon (if available).
Change color when buffer is modified and dim or hide components when
the mode-line is inactive according to configuration."
  (let* ((file-name (buffer-file-name))
         (icon (when (and sleek-modeline-show-icons
                          file-name
                          (featurep 'nerd-icons))
                 (nerd-icons-icon-for-file file-name)))
         (buffer-name (substring-no-properties (format-mode-line "%b")))
         (modified (and sleek-modeline-highlight-modified-buffer-name
                        (buffer-modified-p)))
         (face (if modified
                   'sleek-modeline-buffer-name-modified-face
                 'sleek-modeline-buffer-name-face))
         (highlight-face (if modified
                             'sleek-modeline-buffer-name-modified-highlight-face
                           'sleek-modeline-buffer-name-highlight-face))
         (icon (sleek-modeline--maybe-dim-or-hide
                icon
                sleek-modeline-hide-file-icon-inactive))
         (buffer-name (sleek-modeline--maybe-dim-or-hide
                       (propertize buffer-name
                                   'face face
                                   'mouse-face highlight-face
                                   'help-echo (if file-name
                                                  (abbreviate-file-name file-name)
                                                "Buffer is not associated to a file"))
                       nil)))
    (if icon (concat icon " " buffer-name) buffer-name)))

(sleek-modeline-register-segment 'buffer-name
                                 :fn 'sleek-modeline-buffer-name
                                 :side 'left
                                 :priority 20)

(provide 'sleek-modeline-buffer)
;;; sleek-modeline-buffer.el ends here
