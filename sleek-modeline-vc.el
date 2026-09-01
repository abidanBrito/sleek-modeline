;;; sleek-modeline-vc.el --- Version control segment for sleek-modeline -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Abidán Brito Clavijo
;; Author: Abidán Brito Clavijo <abidan.brito@gmail.com>
;; SPDX-License-Identifier: MIT

;;; Commentary:
;; Version control segment for the `sleek-modeline' package.
;; Displays: [status-symbol] branch-name [icon]
;; The branch name and icon share the mode-line foreground.
;; The leading status symbol is state-coloured: `~' modified, `+' added, etc.

;;; Code:

(require 'vc)
(require 'sleek-modeline-core)

;; NOTE(abi): optional dependency; only gets loaded if available.
(declare-function nerd-icons-octicon "nerd-icons")

(defcustom sleek-modeline-vc-show-icon t
  "Whether to show the branch icon in the version control segment.
Requires `nerd-icons' package to be installed."
  :type 'boolean
  :group 'sleek-modeline)

(defcustom sleek-modeline-vc-use-github-icon nil
  "Whether to use the GitHub icon instead of the git branch icon.
When non-nil, shows the GitHub mark icon.
When nil, shows the git branch icon."
  :type 'boolean
  :group 'sleek-modeline)

(defcustom sleek-modeline-hide-vc-icon-inactive nil
  "Hide version control icon in inactive modelines."
  :type 'boolean
  :group 'sleek-modeline)

(defcustom sleek-modeline-hide-vc-branch-inactive nil
  "Hide the version control branch name in inactive modelines."
  :type 'boolean
  :group 'sleek-modeline)

(defcustom sleek-modeline-vc-show-status-symbol t
  "Whether to show a symbol indicating the VC state after the branch name.
When non-nil, appends a symbol: `~' modified, `+' added, `-' removed,
`!' conflict/needs-merge, `↓' needs-update, `?' unregistered."
  :type 'boolean
  :group 'sleek-modeline)

(defface sleek-modeline-vc-face
  '((t (:weight bold)))
  "Face for the branch icon and branch name in `sleek-modeline'.
Static - does not change with VC state; foreground falls through to mode-line."
  :group 'sleek-modeline-faces)

(defface sleek-modeline-vc-modified-face
  '((t (:inherit font-lock-warning-face :weight bold :slant italic)))
  "Face for version control info when there are modifications.
Used for edited, added, or needs-update states."
  :group 'sleek-modeline-faces)

(defface sleek-modeline-vc-conflict-face
  '((t (:inherit error)))
  "Face for version control info when there are conflicts.
Used for removed, conflict, unregistered, or needs-merge states."
  :group 'sleek-modeline-faces)

(defvar sleek-modeline-vc--enabled nil
  "Non-nil means vc segment hooks are installed globally.")

(defvar-local sleek-modeline-vc--state-cache 'unset
  "Buffer-local cached `vc-state' result.
The symbol `unset' means the cache has not been populated yet.")

(defun sleek-modeline-vc--invalidate-cache ()
  "Invalidate `vc-state' cache for the current buffer."
  (setq sleek-modeline-vc--state-cache 'unset)
  (force-mode-line-update))

(defun sleek-modeline-vc--post-command (_command _flags-or-buffer file-or-list)
  "Invalidate `vc-state' cache for buffers affected by a VC command.
FILE-OR-LIST is either a single file path or a list of file paths.
Implements the `vc-post-command-functions' abnormal hook signature."
  (let ((files (if (listp file-or-list) file-or-list (list file-or-list))))
    (dolist (file files)
      (when (stringp file)
        (when-let* ((buf (find-buffer-visiting (expand-file-name file))))
          (with-current-buffer buf
            (sleek-modeline-vc--invalidate-cache)))))))

(defun sleek-modeline-vc--cached-state ()
  "Return `vc-state' for the current buffer; computed lazily if needed."
  (when (eq sleek-modeline-vc--state-cache 'unset)
    (setq sleek-modeline-vc--state-cache
          (when buffer-file-name
            (condition-case nil
                (vc-state buffer-file-name)
              (error nil)))))
  sleek-modeline-vc--state-cache)

(defun sleek-modeline-vc--branch-icon ()
  "Return the appropriate branch icon based on configuration.
Returns empty string if icons are disabled, nerd-icons is not available,
or if hidden due to inactive mode-line."
  (when (and sleek-modeline-vc-show-icon
             sleek-modeline-show-icons
             (featurep 'nerd-icons))
    (let ((icon (if sleek-modeline-vc-use-github-icon
                    (nerd-icons-octicon "nf-oct-mark_github")
                  (nerd-icons-octicon "nf-oct-git_branch"))))
      (sleek-modeline--maybe-dim-or-hide icon sleek-modeline-hide-vc-icon-inactive))))

(defun sleek-modeline-vc--branch-name ()
  "Get the current branch name from `vc-mode'.
Returns nil if not in a version-controlled file."
  (when (and vc-mode (stringp vc-mode) buffer-file-name)
    (when (string-match "^ [A-Za-z]+[:-]\\(.*\\)" vc-mode)
      (let ((branch (string-trim (substring-no-properties (match-string 1 vc-mode)))))
        (unless (string-empty-p branch)
          branch)))))

(defun sleek-modeline-vc--state-face ()
  "Return the appropriate face based on cached VC state."
  (let ((state (sleek-modeline-vc--cached-state)))
    (cond
     ((memq state '(edited added)) 'sleek-modeline-vc-modified-face)
     ((memq state '(removed conflict unregistered)) 'sleek-modeline-vc-conflict-face)
     ((eq state 'needs-merge) 'sleek-modeline-vc-conflict-face)
     ((eq state 'needs-update) 'sleek-modeline-vc-modified-face)
     (t 'sleek-modeline-vc-face))))

(defun sleek-modeline-vc--status-symbol ()
  "Return a propertized status symbol for the current VC state, or nil if clean."
  (when sleek-modeline-vc-show-status-symbol
    (let* ((state (sleek-modeline-vc--cached-state))
           (sym (cond
                 ((eq state 'edited) "~")
                 ((eq state 'added) "+")
                 ((eq state 'removed) "-")
                 ((memq state '(conflict needs-merge)) "!")
                 ((eq state 'needs-update) "↓")
                 ((eq state 'unregistered) "?"))))
      (when sym
        (let ((face (sleek-modeline-vc--state-face)))
          (propertize sym
                      'face face
                      'mouse-face (list :inherit face :underline t)))))))

(defun sleek-modeline-vc--git-ahead-behind ()
  "Return (BEHIND . AHEAD) commit counts versus the upstream branch, or nil.
BEHIND is the number of commits to pull (down); AHEAD is the number to push
\(up).  Returns nil when Git is unavailable, there is no upstream, or the
command fails."
  (when (executable-find "git")
    (let ((dir default-directory))
      (with-temp-buffer
        (setq default-directory dir)
        (when (eq 0 (ignore-errors
                      (process-file "git" nil t nil "rev-list"
                                    "--count" "--left-right" "@{upstream}...HEAD")))
          (goto-char (point-min))
          (when (looking-at "\\([0-9]+\\)[ \t]+\\([0-9]+\\)")
            (cons (string-to-number (match-string 1))
                  (string-to-number (match-string 2)))))))))

(defun sleek-modeline-vc--help-echo (window _object _pos)
  "Return the version control echo area tooltip for WINDOW's buffer, or nil.
Shows the VC backend and, for Git, the commit counts relative to the
upstream branch."
  (with-current-buffer (window-buffer window)
    (when-let* ((backend (and buffer-file-name (vc-backend buffer-file-name))))
      (let ((name (propertize (symbol-name backend)
                              'face 'sleek-modeline-vc-face)))
        (if (not (eq backend 'Git)) name
          (let ((ab (sleek-modeline-vc--git-ahead-behind)))
            (cond
             ((null ab) name)
             ((and (zerop (car ab)) (zerop (cdr ab)))
              (format "%s :: up to date" name))
             (t (format "%s :: %d ↓, %d ↑" name (car ab) (cdr ab))))))))))

(defun sleek-modeline-vc ()
  "Show version control info as [status-symbol] branch-name [icon].
The branch name and icon use the mode-line foreground.
The status symbol is state-coloured and leads the segment when present.
Returns nil if not in a version-controlled file or if an error occurs."
  (condition-case nil
      (when-let* ((branch (sleek-modeline-vc--branch-name)))
        (let* ((symbol (sleek-modeline-vc--status-symbol))
               (branch-str (propertize branch
                                       'face 'sleek-modeline-vc-face
                                       'mouse-face '(:inherit sleek-modeline-vc-face
                                                     :underline t)))
               (icon (let ((raw (sleek-modeline-vc--branch-icon)))
                       (when raw
                         (let ((fg (face-foreground 'mode-line nil t)))
                           (when fg
                             (add-face-text-property 0 (length raw)
                                                     `(:foreground ,fg) nil raw)))
                         raw)))
               (content (cond
                         ((and symbol icon) (concat symbol " " branch-str " " icon))
                         (symbol (concat symbol " " branch-str))
                         (icon (concat branch-str " " icon))
                         (t branch-str))))
          (sleek-modeline--maybe-dim-or-hide
           (propertize content 'help-echo #'sleek-modeline-vc--help-echo)
           sleek-modeline-hide-vc-branch-inactive)))
    (error nil)))

(defun sleek-modeline-vc-enable ()
  "Enable vc segment hook wiring for cache invalidation.
Call this once inside `sleek-modeline-mode' activation."
  (unless sleek-modeline-vc--enabled
    (setq sleek-modeline-vc--enabled t)
    (add-hook 'after-save-hook #'sleek-modeline-vc--invalidate-cache)
    (add-hook 'find-file-hook #'sleek-modeline-vc--invalidate-cache)
    (add-hook 'vc-checkin-hook #'sleek-modeline-vc--invalidate-cache)
    (add-hook 'vc-post-command-functions #'sleek-modeline-vc--post-command)))

(defun sleek-modeline-vc-disable ()
  "Disable vc segment hook wiring and clear all buffer caches."
  (when sleek-modeline-vc--enabled
    (setq sleek-modeline-vc--enabled nil)
    (remove-hook 'after-save-hook #'sleek-modeline-vc--invalidate-cache)
    (remove-hook 'find-file-hook #'sleek-modeline-vc--invalidate-cache)
    (remove-hook 'vc-checkin-hook #'sleek-modeline-vc--invalidate-cache)
    (remove-hook 'vc-post-command-functions #'sleek-modeline-vc--post-command)
    (dolist (buf (buffer-list))
      (with-current-buffer buf
        (setq sleek-modeline-vc--state-cache 'unset)))))

(sleek-modeline-register-segment 'vc
				 :fn 'sleek-modeline-vc
				 :side 'right
				 :priority 20
				 :separator t
				 :on-enable 'sleek-modeline-vc-enable
				 :on-disable 'sleek-modeline-vc-disable)

(provide 'sleek-modeline-vc)
;;; sleek-modeline-vc.el ends here
