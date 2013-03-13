;; colors
(add-to-list 'custom-theme-load-path "~/my_src/dotfiles/")
(load-theme 'telstar t)

(setq package-archives '(("ELPA" . "http://tromey.com/elpa/")
                         ("gnu" . "http://elpa.gnu.org/packages/")
                         ("marmalade" . "http://marmalade-repo.org/packages/")))

;; better defaults
(setq-default visible-bell nil)

(global-linum-mode 1)

(global-set-key (kbd "C-c c") 'comment-dwim)

(set-face-attribute 'default nil :height 140)

(defalias 'yes-or-no-p 'y-or-n-p)

(show-paren-mode 1)

(setq-default tab-width 2)
(setq-default standard-indent 2)
(setq-default initial-buffer-choice t)
(setq-default initial-scratch-message "")
(setq-default show-trailing-whitespace t)

(setq-default vc-follow-symlinks t)

(if (fboundp 'tool-bar-mode) (tool-bar-mode -1))
(if (fboundp 'menu-bar-mode) (menu-bar-mode -1))
(if (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))

(setq inhibit-startup-message t)

;; Yes! Source: http://news.ycombinator.com/item?id=5197828
(setq mac-option-key-is-meta nil)
(setq mac-command-key-is-meta t)
(setq mac-command-modifier 'meta)
(setq mac-option-modifier nil)

(add-to-list 'auto-mode-alist '("\\.md$" . markdown-mode))

;; For later.
;;(add-to-list 'auto-mode-alist '("\\.pp$" . puppet-mode))
;;(add-to-list 'auto-mode-alist '("Vagrantfile$" . ruby-mode))

(add-to-list 'load-path "~/git_src/go-mode.el/" t)
(require 'go-mode)
