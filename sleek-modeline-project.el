;;; sleek-modeline-project.el --- Project segment for sleek-modeline -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Abidán Brito Clavijo
;; Author: Abidán Brito Clavijo <abidan.brito@gmail.com>
;; SPDX-License-Identifier: MIT

;;; Commentary:
;; Project name segment for the `sleek-modeline' package.
;; Supports both `projectile' and the built-in `project.el' backends,
;; preferring projectile when both are active.

;;; Code:

(require 'sleek-modeline-core)

;; NOTE(abi): optional dependencies, declared to silence the byte-compiler.
(eval-when-compile
  (declare-function projectile-project-name "projectile")
  (declare-function projectile-project-root "projectile")
  (declare-function project-current "project")
  (declare-function project-root "project")
  (defvar projectile-mode))

(defcustom sleek-modeline-hide-project-name-inactive nil
  "Hide project name in inactive modelines."
  :type 'boolean
  :group 'sleek-modeline)

(defface sleek-modeline-project-face
  '((t (:inherit font-lock-string-face :weight bold :slant normal)))
  "Face for the project name in `sleek-modeline'."
  :group 'sleek-modeline-faces)

(defface sleek-modeline-project-highlight-face
  '((t (:inherit sleek-modeline-project-face :underline t)))
  "Face used to highlight the project segment on mouse hover."
  :group 'sleek-modeline-faces)

(defun sleek-modeline-project--info ()
  "Return project information as a plist, or nil if not in a project.
Prefers `projectile' when active, falls back to `project.el'.
  :backend STRING - Backend name.
  :name    STRING - Project name.
  :root    STRING - Project root directory (with trailing slash)."
  (cond
   ;; `projectile' backend
   ;; NOTE(abi): sentinel value \"-\" means no project.
   ((and (featurep 'projectile)
         (bound-and-true-p projectile-mode))
    (let ((name (projectile-project-name)))
      (unless (string= name "-")
        (list :backend "Projectile"
              :name name
              :root (projectile-project-root)))))

   ;; `project.el' backend
   ((featurep 'project)
    (when-let* ((project (project-current))
                (root (project-root project)))
      (list :backend "Project.el"
            :name (or (and (boundp 'project-vc-name) project-vc-name)
                      (file-name-nondirectory (directory-file-name root)))
            :root root)))))

(defun sleek-modeline-project ()
  "Return the propertized project name for the mode-line, or nil.
The hover tooltip shows the active backend and the project root."
  (condition-case nil
      (when-let* ((info (sleek-modeline-project--info)))
	(sleek-modeline--maybe-dim-or-hide
	 (propertize (plist-get info :name)
		     'face 'sleek-modeline-project-face
		     'mouse-face 'sleek-modeline-project-highlight-face
		     'help-echo (format "%s :: %s"
					(propertize (plist-get info :backend)
						    'face 'sleek-modeline-project-face)
					(abbreviate-file-name
					 (directory-file-name
					  (plist-get info :root)))))
	 sleek-modeline-hide-project-name-inactive))
    (error nil)))

(sleek-modeline-register-segment 'project
				 :fn 'sleek-modeline-project
				 :side 'left
				 :priority 10
				 :separator t
				 :condition 'sleek-modeline-enable-project)

(provide 'sleek-modeline-project)
;;; sleek-modeline-project.el ends here
