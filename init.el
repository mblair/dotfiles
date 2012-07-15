(setq package-archives '(("ELPA" . "http://tromey.com/elpa/")
                         ("gnu" . "http://elpa.gnu.org/packages/")
                         ("marmalade" . "http://marmalade-repo.org/packages/")))

(defvar mah-packages '(starter-kit starter-kit-lisp starter-kit-ruby)
  "A list of packages that I want to ensure are installed at launch.")

;;(add-to-list 'custom-theme-load-path "~/git_src/emacs-color-theme-solarized/")
(add-to-list 'custom-theme-load-path "~/.emacs.d/elpa/color-theme-solarized-20120301")
(load-theme 'solarized-dark t)

(setq-default visible-bell nil)

(global-linum-mode 1)
