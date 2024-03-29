(add-to-list 'custom-theme-load-path "~/my_src/dotfiles/")
(setq mac-command-modifier 'meta)
(setq mac-option-modifier 'super)
(setq prelude-whitespace nil)
;;(global-linum-mode 1)
(global-set-key (kbd "M-l") 'goto-line)
(global-set-key "\C-c c" 'comment-dwim)
(global-set-key (kbd "C-SPC") 'easy-mark)
(prelude-require-package 'warm-night-theme)
(prelude-require-package 'darktooth-theme)
(prelude-require-package 'tide)
(prelude-require-package 'ag)
(prelude-require-package 'nord-theme)
(prelude-require-package 'markdown-mode)
(prelude-require-package 'terraform-mode)
(prelude-require-package 'typescript-mode)
(custom-set-variables
 '(terraform-format-on-save t))
;;(load-theme 'darktooth t)
;;(load-theme 'warm-night t)
(load-theme 'ariake t)
(set-face-attribute 'default nil :height 140)
(set-face-attribute 'default nil :family "B612 Mono")
(setq whitespace-style (delete 'lines-tail whitespace-style))
(defun my/setup-go-mode-gofmt-hook ()
  ;; Use goimports instead of go-fmt
  (setq gofmt-command "goimports")
  ;; Call Gofmt before saving
  (add-hook 'before-save-hook 'gofmt-before-save))
(add-hook 'go-mode-hook 'my/setup-go-mode-gofmt-hook)
(setq ruby-insert-encoding-magic-comment nil)
