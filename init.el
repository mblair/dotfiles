(require 'package)

(setq package-archives '(
                         ("melpa" . "http://melpa.milkbox.net/packages/")
                         ))

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
                      ;; rainbow-mode
                      scala-mode2
                      rust-mode
                      clojure-mode
                      clojure-test-mode
                      coffee-mode
                      auto-complete
                      ac-nrepl
                      cider
                      kill-ring-search
                      expand-region
                      multi-term
                      anzu
                      fiplr
                      ido-vertical-mode
                      latest-clojure-libraries

                      ;; colors:
                      subatomic-theme
                      color-theme ;; http://www.nongnu.org/color-theme/
                      color-theme-sanityinc-solarized
                      color-theme-sanityinc-tomorrow
                      zenburn-theme
                      soothe-theme
                      solarized-theme ;; this is the one from bbatsov
                      planet-theme
                      niflheim-theme
                      distinguished-theme
                      colorsarenice-theme
                      noctilux-theme
                      darkburn-theme
                      clues-theme
                      gruber-darker-theme
                      ample-theme
                      phoenix-dark-pink-theme
                      ))

(dolist (p my-packages)
  (when (not (package-installed-p p))
    (package-install p)))

(require 'cl)

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
(set-face-attribute 'default nil :family "Inconsolata")

;; http://stackoverflow.com/questions/7616761/even-when-emacsclient-is-started-in-a-terminal-window-system-is-non-nil
(defun color-config (&optional frame)
  (select-frame frame)
  (if window-system (load-theme 'solarized-dark t)
    (load-theme 'zenburn t)))

;; for emacsclient:
(add-hook 'after-make-frame-functions 'color-config)

;; for regular emacs:
(color-config (selected-frame))

(if (equal system-type 'darwin)
    (progn
      (setq prefix "~/external_src/")
      (setq go-location "~/rebuild_src/go/")
      (add-to-list 'custom-theme-load-path "~/my_src/dotfiles/")
      )
  (progn
    (setq prefix "/mnt/external/clones/")
    (setq go-location (concat prefix "go/"))
    (add-to-list 'custom-theme-load-path "~/mblair_src/dotfiles/")
    ))

(add-to-list 'custom-theme-load-path (concat prefix "emacs-color-themes/themes"))
(add-to-list 'custom-theme-load-path (concat prefix "emacs-deep-thought-theme"))

(add-to-list 'load-path (concat prefix "emacs-powerline"))
(require 'powerline)

(load (concat prefix "auto-fill-mode-inhibit"))
(require 'auto-fill-inhibit)
(add-to-list 'auto-fill-inhibit-list "flipboard_src/ops")

(add-to-list 'load-path (concat go-location "misc/emacs"))
(require 'go-mode-load)

(load (concat prefix "go.tools/cmd/oracle/oracle"))
(require 'go-oracle)
(setq go-oracle-command "~/gopath/bin/oracle")

(add-to-list 'load-path (concat prefix "gocode/emacs"))

(require 'go-autocomplete)
(require 'auto-complete-config)
(ac-config-default)

;; thanks, dustin + bradfitz
(defun my-go-mode-hook ()
  (setq gofmt-command "goimports")
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

;; basically all of this multi-term customization is from here:
;; http://rawsyntax.com/blog/learn-emacs-zsh-and-multi-term/

(require 'multi-term)

;; todo: fix this on linux
(setq multi-term-program "/usr/local/bin/zsh")

(add-hook 'term-mode-hook
          (lambda ()
            (setq term-buffer-maximum-size 10000)))

(add-hook 'term-mode-hook
          (lambda ()
            (add-to-list 'term-bind-key-alist '("M-[" . multi-term-prev))
            (add-to-list 'term-bind-key-alist '("M-]" . multi-term-next))))

(add-hook 'term-mode-hook
          (lambda ()
            (define-key term-raw-map (kbd "C-y") 'term-paste)))

;; TODO Find out why this is screwing up the bg color on linum-mode.
;; (require 'anzu)
;; (global-anzu-mode +1)

(setq cider-repl-popup-stacktraces t)

(global-rainbow-delimiters-mode)

;; Don't `C-x o` to a Cider REPL.
;; That's what `C-c C-z` is for.
;; Source:
;; http://stackoverflow.com/questions/4941960/how-do-i-make-emacs-other-window-command-ignore-terminal-windows/4948239#4948239
(defvar avoid-window-regexp "^\*cider\-repl")
(defun my-other-window ()
  "Similar to 'other-window, only try to avoid windows whose buffers match avoid-window-regexp"
  (interactive)
  (let* ((window-list (delq (selected-window) (window-list)))
         (filtered-window-list (remove-if
                                (lambda (w)
                                  (string-match-p avoid-window-regexp (buffer-name (window-buffer w))))
                                window-list)))
    (if filtered-window-list
        (select-window (car filtered-window-list))
      (and window-list
           (select-window (car window-list))))))

(global-set-key (kbd "C-x o") 'my-other-window)

(add-hook 'cider-repl-mode-hook 'paredit-mode)

;; C-c C-z to access it.
(setq cider-repl-pop-to-buffer-on-connect nil)

(setq cider-popup-stacktraces nil)

(savehist-mode 1)

(global-set-key (kbd "C-x f") 'fiplr-find-file)

(require 'ido-vertical-mode)
(ido-mode 1)
(ido-vertical-mode 1)

; http://www.emacswiki.org/emacs/TransparentEmacs
(defun toggle-transparency ()
  (interactive)
  (if (/=
       (cadr (frame-parameter nil 'alpha))
       100)
      (set-frame-parameter nil 'alpha '(100 100))
    (set-frame-parameter nil 'alpha '(85 50))))

(global-set-key (kbd "C-c t") 'toggle-transparency)

;; (defun cider-namespace-refresh ()
;;   (interactive)
;;   (cider-interactive-eval
;;    "(require 'clojure.tools.namespace.repl)
;;     (clojure.tools.namespace.repl/refresh)"))

;; (define-key clojure-mode-map (kbd "M-r") 'cider-namespace-refresh)
