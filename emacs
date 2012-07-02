;; colorssssss
(add-to-list 'custom-theme-load-path "~/git_src/emacs-color-theme-solarized/")
(load-theme 'solarized-dark t)

;; electric rubies
(add-to-list 'load-path "~/.emacs.d/elpa/ruby-electric-1.1/")
(require 'ruby-electric)
(add-hook 'ruby-mode-hook (lambda () (ruby-electric-mode t)))

;; markdown mode, found [here](http://jblevins.org/git/markdown-mode.git)
(add-to-list 'load-path "~/.emacs.d/")
(autoload 'markdown-mode "markdown-mode"
					"Major mode for editing Markdown files" t)
(setq auto-mode-alist (cons '("\\.md" . markdown-mode) auto-mode-alist)
(setq auto-mode-alist (cons '("\\.ronn" . markdown-mode) auto-mode-alist)

;; cool stuff to enable
(show-paren-mode 1)

;; better defaults
(setq-default tab-width 2)
(setq-default standard-indent 2)
(setq-default initial-buffer-choice t)
(setq-default initial-scratch-message "")
(setq-default show-trailing-whitespace t)

(add-hook 'before-save-hook 'delete-trailing-whitespace)

;; stupid stuff to disable
(setq inhibit-startup-message t)
(setq-default make-backup-files nil)
(tool-bar-mode -1)
(scroll-bar-mode -1)

(set-face-attribute 'default nil :height 140)

(setq package-archives '(("ELPA" . "http://tromey.com/elpa/")
                         ("gnu" . "http://elpa.gnu.org/packages/"))