;;; Directory Local Variables -*- no-byte-compile: t; -*-

((emacs-lisp-mode
  . ((indent-tabs-mode . nil)
     (sentence-end-double-space . t)
     (require-final-newline . t)
     ;; Let flycheck resolve intra-package `require' calls
     (flycheck-emacs-lisp-load-path . ("./" "../"))
     ;; Let flycheck find locally installed packages
     (flycheck-emacs-lisp-package-user-dir . ".local-elpa"))))
