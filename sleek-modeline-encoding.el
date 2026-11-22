;;; sleek-modeline-encoding.el --- Buffer encoding segment for sleek-modeline -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Abidán Brito Clavijo
;; Author: Abidán Brito Clavijo <abidan.brito@gmail.com>
;; SPDX-License-Identifier: MIT

;;; Commentary:
;; Buffer encoding segment for the `sleek-modeline' package.  Displays the
;; coding system of the current buffer (file-backed buffers only).

;;; Code:

(require 'sleek-modeline-core)

(defvar sleek-modeline-encoding--keymap
  (let ((map (make-sparse-keymap)))
    (define-key map [mode-line mouse-1] #'sleek-modeline-encoding--set-coding-system)
    map)
  "Keymap active on the encoding segment of `sleek-modeline'.")

(defcustom sleek-modeline-hide-encoding-inactive nil
  "Hide the encoding indicator in inactive modelines."
  :type 'boolean
  :group 'sleek-modeline)

(defcustom sleek-modeline-encoding-hide-utf-8 nil
  "When non-nil, suppress the encoding segment for UTF-8 buffers.
Since most files are UTF-8, hiding it reduces clutter when only non-standard
encodings are worth surfacing."
  :type 'boolean
  :group 'sleek-modeline)

(defcustom sleek-modeline-encoding-hide-undecided nil
  "When non-nil, suppress the encoding segment for undecided buffers.
This covers plain ASCII files, whose encoding cannot be detected, and
`prefer-utf-8'."
  :type 'boolean
  :group 'sleek-modeline)

(defface sleek-modeline-encoding-face
  '((t (:inherit font-lock-doc-face :slant normal)))
  "Face for the buffer encoding indicator in `sleek-modeline'."
  :group 'sleek-modeline-faces)

(defface sleek-modeline-encoding-highlight-face
  '((t (:inherit sleek-modeline-encoding-face :underline t)))
  "Face used to highlight the encoding segment on mouse hover."
  :group 'sleek-modeline-faces)

(defun sleek-modeline-encoding--set-coding-system ()
  "Run `set-buffer-file-coding-system' for the clicked buffer."
  (interactive "@")
  (call-interactively #'set-buffer-file-coding-system))

(defun sleek-modeline--encoding ()
  "Return (SHORT . LONG) descriptions of the buffer's coding system.
SHORT is the compact segment label; LONG is the full name for the hover tooltip."
  (let* ((coding-system buffer-file-coding-system)
         (category (plist-get (coding-system-plist coding-system) :category)))
    (cons (if (eq category 'coding-category-utf-8)
              "UTF-8"
            (let ((name (upcase (symbol-name (coding-system-base coding-system)))))
              (string-replace "-AUTO" " AUTO"
                              (string-replace "-WITH-SIGNATURE" " BOM" name))))
          (symbol-name coding-system))))

(defun sleek-modeline-encoding-indicator ()
  "Return a propertized encoding string for file-backed buffers, or nil.
Dim or hide in inactive mode-lines according to configuration."
  (when buffer-file-name
    (let* ((encoding-pair (sleek-modeline--encoding))
           (short (car encoding-pair))
           (long (cdr encoding-pair)))
      (unless (or (and sleek-modeline-encoding-hide-utf-8
                       (string= short "UTF-8"))
                  (and sleek-modeline-encoding-hide-undecided
                       (eq (coding-system-category buffer-file-coding-system)
                           'coding-category-undecided)))
        (sleek-modeline--maybe-dim-or-hide
         (propertize short
                     'face 'sleek-modeline-encoding-face
                     'mouse-face 'sleek-modeline-encoding-highlight-face
                     'help-echo (concat "Encoding: " long)
                     'local-map sleek-modeline-encoding--keymap)
         sleek-modeline-hide-encoding-inactive)))))

(sleek-modeline-register-segment 'encoding
                                 :fn 'sleek-modeline-encoding-indicator
                                 :side 'right
                                 :priority 11
                                 :separator t)

(provide 'sleek-modeline-encoding)
;;; sleek-modeline-encoding.el ends here
