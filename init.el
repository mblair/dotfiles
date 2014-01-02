(require 'package)

(setq package-archives '(("ELPA" . "http://tromey.com/elpa/")
                         ("gnu" . "http://elpa.gnu.org/packages/")
                         ("marmalade" . "http://marmalade-repo.org/packages/")
			 ("melpa" . "http://melpa.milkbox.net/packages/")))

(package-initialize)
(when (not package-archive-contents)
  (package-refresh-contents))

(defvar my-packages '(starter-kit
                      starter-kit-lisp
                      starter-kit-bindings
                      starter-kit-eshell
                      markdown-mode
                      coffee-mode
                      js2-mode
                      yaml-mode
                      puppet-mode
                      rainbow-delimiters
                      rainbow-mode
                      scala-mode2
                      clojure-mode
                      clojure-test-mode
                      auto-complete
                      ac-nrepl
                      cider
                      kill-ring-search
                      expand-region

                      ;; colors:
                      color-theme ;; http://www.nongnu.org/color-theme/
                      color-theme-sanityinc-solarized
                      color-theme-sanityinc-tomorrow
                      zenburn-theme
                      color-theme-heroku
                      soothe-theme
                      deep-thought-theme
                      solarized-theme ;; this is the one from bbatsov
                      ))

(dolist (p my-packages)
  (when (not (package-installed-p p))
  (package-install p)))

;; better defaults
(setq-default visible-bell nil)

(global-linum-mode 1)
(global-set-key (kbd "C-c c") 'comment-dwim)

(global-set-key (kbd "M-l") 'goto-line)

(setq x-select-enable-clipboard t)
(global-set-key (kbd "M-c") 'kill-ring-save)

(set-face-attribute 'default nil :height 160)

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
(setq-default make-backup-files nil)
(add-hook 'before-save-hook 'delete-trailing-whitespace)

;; Yes! Source: http://news.ycombinator.com/item?id=5197828
(setq mac-option-key-is-meta nil)
(setq mac-command-key-is-meta t)
(setq mac-command-modifier 'meta)
(setq mac-option-modifier nil)

(require 'yaml-mode)

(add-to-list 'auto-mode-alist '("\\.yml$" . yaml-mode))
(add-to-list 'auto-mode-alist '("\\.md$" . markdown-mode))
(add-to-list 'auto-mode-alist '("\\.ronn" . markdwon-mode))
(add-to-list 'auto-mode-alist '("\\.pp$" . puppet-mode))
(add-to-list 'auto-mode-alist '("Vagrantfile$" . ruby-mode))
(add-to-list 'auto-mode-alist '("\\.ru" . ruby-mode))
(add-to-list 'auto-mode-alist '("\\.gemspec" . ruby-mode))
(add-to-list 'auto-mode-alist '("Rakefile$" . ruby-mode))
(add-to-list 'auto-mode-alist '("Cakefile$" . coffee-mode))

(set-face-attribute 'default nil :height 160)
(set-face-attribute 'default nil :family "Ubuntu Mono")

;; http://stackoverflow.com/questions/7616761/even-when-emacsclient-is-started-in-a-terminal-window-system-is-non-nil
(defun color-config (&optional frame)
  (select-frame frame)
  (if window-system (load-theme 'solarized-dark t)
    (load-theme 'zenburn t)))

;; for emacsclient:
(add-hook 'after-make-frame-functions 'color-config)

;; for regular emacs:
(color-config (selected-frame))

;; for git-sourced colors:
(add-to-list 'custom-theme-load-path "~/my_src/dotfiles/")
(add-to-list 'custom-theme-load-path "~/mblair_src/dotfiles/")
;; (load-theme 'telstar t)

(add-to-list 'custom-theme-load-path "/mnt/external/clones/color-theme-heroku")
(add-to-list 'custom-theme-load-path "/external_src/color-theme-heroku")
;; (color-theme-heroku)

;; ;; go stuff
;; (add-to-list 'load-path "/mnt/external/clones/go/misc/emacs/")
;; (add-to-list 'load-path "~/rebuild_src/go/misc/emacs/")

(add-to-list 'load-path "/mnt/external/clones/go-mode.el/")
(add-to-list 'load-path "~/external_src/go-mode.el/")

(require 'go-mode)

(add-to-list 'load-path "/mnt/external/clones/gocode/emacs/")
(add-to-list 'load-path "~/external_src/gocode/emacs")

(require 'go-autocomplete)
(require 'auto-complete-config)
(ac-config-default)

;; thanks, dustin
(defun my-go-mode-hook ()
  (add-hook 'before-save-hook 'gofmt-before-save)
  (if (not (string-match "go" compile-command))
      (set (make-local-variable 'compile-command)
           "go vet && go build -v"))
  (setq tab-width 8 indent-tabs-mode 1)
  (local-set-key (kbd "M-.") 'godef-jump))

(add-hook 'go-mode-hook 'my-go-mode-hook)

(global-set-key (kbd "C-c C-c") 'compile)

(autoload 'kill-ring-search "kill-ring-search"
  "Search the kill ring in the minibuffer."
  (interactive))

(global-set-key "\M-\C-y" 'kill-ring-search)

(require 'expand-region)
(global-set-key (kbd "C-=") 'er/expand-region)

;; TODO: learn some damned elisp and make these loads work on Linux
;; and OS X and not be onerous to maintain.

(load "~/external_src/go.tools/cmd/oracle/oracle")
(require 'go-oracle)
(setq go-oracle-command "~/gopath/bin/oracle")
