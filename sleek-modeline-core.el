;;; sleek-modeline-core.el --- Helper functions for sleek-modeline -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Abidán Brito Clavijo
;; Author: Abidán Brito Clavijo <abidan.brito@gmail.com>
;; SPDX-License-Identifier: MIT

;;; Commentary:
;; Core functionality for the `sleek-modeline' package.  That includes functions,
;; customizable variables and face definitions.

;;; Code:

(require 'color)
(require 'cl-lib)

(defvar sleek-modeline--segment-registry nil
  "List of registered segment descriptors (plists).
Each entry is a plist with keys.
  :name       symbol - Unique segment identifier.
  :fn         symbol - Display function (returns string or nil).
  :side       `left' or `right'.
  :priority   integer - Lower means closer to the outer edge.
  :separator  nil | t | STRING - nil: no suffix; t: standard separator;
              string: literal string to append after a non-nil result.
  :condition  symbol - Variable that must be non-nil to display the segment.
  :on-enable  symbol - Function called when `sleek-modeline-mode' activates.
  :on-disable symbol - Function called when `sleek-modeline-mode' deactivates.")

(defun sleek-modeline-register-segment (name &rest props)
  "Register a segment under NAME with the given PROPS plist.
If a segment with NAME already exists it is replaced.
See `sleek-modeline--segment-registry' for valid keys."
  (setq sleek-modeline--segment-registry
        (cons (append (list :name name) props)
              (seq-remove (lambda (s) (eq (plist-get s :name) name))
                          sleek-modeline--segment-registry))))

(defgroup sleek-modeline nil
  "Customization group for `sleek-modeline'."
  :group 'mode-line
  :prefix "sleek-modeline-")

(defgroup sleek-modeline-faces nil
  "Customization group for faces used by `sleek-modeline'."
  :group 'sleek-modeline
  :group 'faces)

(defcustom sleek-modeline-size 'small
  "Size of the mode-line.
This affects the visual height through the box property."
  :type '(choice
          (const :tag "small" small)
          (const :tag "medium" medium)
          (const :tag "large" large))
  :group 'sleek-modeline
  :set (lambda (symbol value)
         (set-default symbol value)
         ;; Only update if mode is currently active
         (when (and (boundp 'sleek-modeline-mode)
                    sleek-modeline-mode)
           (sleek-modeline--update-faces))))

(defcustom sleek-modeline-height nil
  "Custom height for the mode-line box property.
When nil, uses the value determined by `sleek-modeline-size'.
When set to a number, overrides the size setting."
  :type '(choice (const :tag "Use size setting" nil)
                 (integer :tag "Custom height"))
  :group 'sleek-modeline
  :set (lambda (symbol value)
         (set-default symbol value)
         ;; Only update if mode is currently active
         (when (and (boundp 'sleek-modeline-mode)
                    sleek-modeline-mode)
           (sleek-modeline--update-faces))))

(defcustom sleek-modeline-show-icons t
  "Whether to show nerd icons in the modeline.
Requires `nerd-icons' package to be installed."
  :type 'boolean
  :group 'sleek-modeline)

(defcustom sleek-modeline-separator " » "
  "Separator string used between segments in the mode-line."
  :type 'string
  :group 'sleek-modeline)

(defcustom sleek-modeline-background nil
  "Custom background for the mode-line.
If nil, derives from `default` face."
  :type '(choice (const :tag "Derive from default" nil)
                 color)
  :group 'sleek-modeline)

(defcustom sleek-modeline-hide-inactive nil
  "Whether to hide/blank the mode-line on unselected windows.
When non-nil, all segment are hidden and the bar blends into the buffer's
background on non-selected windows.  The bar keeps its height, so changing
focus never shifts the window layout."
  :type 'boolean
  :group 'sleek-modeline
  :set (lambda (symbol value)
         (set-default symbol value)
         (when (and (boundp 'sleek-modeline-mode)
                    sleek-modeline-mode)
           (sleek-modeline--update-faces))))

(defface sleek-modeline-separator-face
  '((t (:inherit shadow)))
  "Face for the separator between segments in `sleek-modeline'."
  :group 'sleek-modeline-faces)

(defun sleek-modeline--get-height ()
  "Get mode-line height based on `sleek-modeline-size' or `sleek-modeline-height'.
Returns the box line-width value to use for the mode-line."
  (or sleek-modeline-height
      (pcase sleek-modeline-size
        ('small 1)
        ('medium 5)
        ('large 10))))

(defun sleek-modeline--update-faces ()
  "Update mode-line face attributes based on current height settings.
Derives mode-line backgrounds by darkening the current `default' face,
ensuring the modeline is always visually distinct from buffer content."
  (let* ((modeline-height (sleek-modeline--get-height))
         ;; NOTE(abi): `face-background' can return nil or unspecified-bg on terminal frames
         ;;            or before a theme has set the default face.  We filter those out so
         ;;            that colour blending functions never receive unparsable input.
         (raw-background (or sleek-modeline-background
                             (face-background 'default nil t)))
         (default-background (if (sleek-modeline--valid-color-p raw-background)
                                 raw-background
                               "#000000"))
         (modeline-background (sleek-modeline--darken default-background 0.30))
         (modeline-inactive-background (if sleek-modeline-hide-inactive
                                           default-background
                                         (sleek-modeline--darken default-background 0.15))))
    (when (facep 'mode-line)
      (set-face-attribute 'mode-line nil
                          :background modeline-background
                          :box `(:line-width ,modeline-height :color ,modeline-background)
                          :underline nil))
    (when (facep 'mode-line-inactive)
      (set-face-attribute 'mode-line-inactive nil
                          :background modeline-inactive-background
                          :box `(:line-width ,modeline-height :color ,modeline-inactive-background)
                          :underline nil))
    (sleek-modeline--update-separator-face)
    (force-mode-line-update t)))

(defun sleek-modeline--separator ()
  "Return the propertized segment separator."
  (propertize sleek-modeline-separator 'face 'sleek-modeline-separator-face))

(defun sleek-modeline--inactive-p ()
  "Return non-nil if the current mode-line is inactive."
  (not (mode-line-window-selected-p)))

(defun sleek-modeline--hide-inactive-p ()
  "Return non-nil when the current window's mode-line should be hidden/blanked."
  (and sleek-modeline-hide-inactive (sleek-modeline--inactive-p)))

(defun sleek-modeline--dim (str)
  "Return a copy of STR dimmed for an inactive mode-line.
Only the foreground colour is overlaid (with the `mode-line-inactive'
foreground).  The segment's own weight, slant, and size are preserved so that
it keeps the same width whether or not its window is selected."
  (let ((dimmed (copy-sequence str)))
    (add-face-text-property 0 (length dimmed)
                            (list :foreground
                                  (face-foreground 'mode-line-inactive nil t))
                            nil dimmed)
    dimmed))

(defun sleek-modeline--dim-background (face)
  "Return a dimmed version of FACE by blending its background."
  (let* ((bg (face-background face nil t))
         (inactive-bg (face-background 'mode-line-inactive nil t))
         (dimmed-bg (if (and bg inactive-bg)
                        (sleek-modeline--blend-colors bg inactive-bg 0.5)
                      inactive-bg)))
    `(:inherit ,face :background ,dimmed-bg)))

(defun sleek-modeline--dim-icon (icon)
  "Return ICON dimmed for inactive mode-line while preserving its foreground."
  (let* ((bg (face-background 'mode-line-inactive nil t))
         ;; derive a temporary face with blended background
         (dim-face (make-face 'sleek-modeline-temp-dim-face)))
    (set-face-attribute dim-face nil
                        :inherit (or (get-text-property 0 'face icon) 'default)
                        :background bg)
    (propertize icon 'face dim-face)))

(defun sleek-modeline--maybe-dim-or-hide (str hide-inactive)
  "Return STR, dimmed or hidden if inactive.
If HIDE-INACTIVE is non-nil, return nil when inactive."
  (cond
   ((not str) nil)
   ((sleek-modeline--inactive-p)
    (unless hide-inactive
      (sleek-modeline--dim str)))
   (t str)))

(defun sleek-modeline--valid-color-p (color)
  "Return non-nil if COLOR is a string that `color-name-to-rgb' can parse."
  (and (stringp color)
       (not (string-prefix-p "unspecified" color))
       (color-name-to-rgb color)))

(defun sleek-modeline--blend-colors (c1 c2 alpha)
  "Blend C1 toward C2 by ALPHA (0.0 = C2, 1.0 = C1).
Returns C1 unchanged when either color cannot be parsed."
  (let ((rgb1 (and (stringp c1) (color-name-to-rgb c1)))
        (rgb2 (and (stringp c2) (color-name-to-rgb c2))))
    (if (and rgb1 rgb2)
        (apply #'color-rgb-to-hex
               (cl-mapcar (lambda (a b) (+ (* alpha a) (* (- 1.0 alpha) b)))
                          rgb1 rgb2))
      (or c1 c2))))

(defun sleek-modeline--darken (color amount)
  "Darken COLOR by AMOUNT (0.0 = unchanged, 1.0 = black)."
  (sleek-modeline--blend-colors color "#000000" (- 1.0 amount)))

(defun sleek-modeline--update-separator-face ()
  "Set separator face to a dimmed version of the shadow face foreground."
  (let ((shadow-fg (face-foreground 'shadow nil t))
        (bg (face-background 'default nil t)))
    (when (and shadow-fg bg)
      (set-face-attribute 'sleek-modeline-separator-face nil
                          :foreground (sleek-modeline--blend-colors shadow-fg bg 0.5)))))

(provide 'sleek-modeline-core)
;;; sleek-modeline-core.el ends here
