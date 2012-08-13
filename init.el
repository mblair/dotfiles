(setq package-archives '(("ELPA" . "http://tromey.com/elpa/")
                         ("gnu" . "http://elpa.gnu.org/packages/")
                         ("marmalade" . "http://marmalade-repo.org/packages/")))

(defvar mah-packages '(starter-kit starter-kit-lisp starter-kit-ruby)
  "A list of packages that I want to ensure are installed at launch.")

(add-to-list 'custom-theme-load-path "~/git_src/emacs-color-theme-solarized/")
(load-theme 'solarized-dark t)

(setq-default visible-bell nil)

(global-linum-mode 1)

(add-to-list 'auto-mode-alist '("\\.pp$" . puppet-mode))
(add-to-list 'auto-mode-alist '("riemann.config$" . clojure-mode))
(add-to-list 'auto-mode-alist '("Vagrantfile$" . ruby-mode))
(add-to-list 'auto-mode-alist '("\\.md$" . markdown-mode))

(global-set-key (kbd "C-c c") 'comment-dwim)
