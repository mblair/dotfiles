(setq package-archives '(("ELPA" . "http://tromey.com/elpa/")
                         ("gnu" . "http://elpa.gnu.org/packages/")
                         ("marmalade" . "http://marmalade-repo.org/packages/")))

(defvar mah-packages '(starter-kit starter-kit-lisp starter-kit-ruby)
  "A list of packages that I want to ensure are installed at launch.")

(add-to-list 'custom-theme-load-path "~/git_src/emacs-color-theme-solarized/")
(load-theme 'solarized-dark t)

(setq-default visible-bell nil)

(global-linum-mode 1)

;; Automatically save and restore sessions
;; http://stackoverflow.com/questions/4477376/some-emacs-desktop-save-questions-how-to-change-it-to-save-in-emacs-d-emacs
(setq desktop-dirname             "~/.emacs.d/desktop/"
      desktop-base-file-name      "emacs.desktop"
      desktop-base-lock-name      "lock"
      desktop-path                (list desktop-dirname)
      desktop-save                t
      desktop-files-not-to-save   "^$" ;reload tramp paths
      desktop-load-locked-desktop nil)
(desktop-save-mode 1)
