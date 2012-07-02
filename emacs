;; colorssssss
(add-to-list 'custom-theme-load-path "~/git_src/emacs-color-theme-solarized/")
(load-theme 'solarized-dark t)

;; cool stuff to enable
(show-paren-mode 1)

;; better defaults
(setq-default tab-width 2)
(setq-default standard-indent 2)
(setq-default initial-buffer-choice t)
(setq-default initial-scratch-message "")
(setq show-trailing-whitespace t)

;; stupid stuff to disable
(setq inhibit-startup-message t)
(setq-default make-backup-files nil)
(tool-bar-mode -1)
(scroll-bar-mode -1)

(set-face-attribute 'default nil :height 140)

(setq package-archives '(("ELPA" . "http://tromey.com/elpa/")
                         ("gnu" . "http://elpa.gnu.org/packages/"))