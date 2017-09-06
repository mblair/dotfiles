(add-to-list 'custom-theme-load-path "~/my_src/dotfiles/")
(setq mac-command-modifier 'meta)
(setq mac-option-modifier 'super)
(setq prelude-whitespace nil)
(global-linum-mode 1)
(global-set-key (kbd "M-l") 'goto-line)
(global-set-key "\C-c c" 'comment-dwim)
(prelude-require-package 'warm-night-theme)
(prelude-require-package 'lsp-rust)
(prelude-require-package 'darktooth-theme)
(prelude-require-package 'tide)
(prelude-require-package 'ag)
(prelude-require-package 'nord-theme)
;;(load-theme 'darktooth t)
(load-theme 'warm-night t)
(set-face-attribute 'default nil :height 140)
(set-face-attribute 'default nil :family "Fira Code")
(setq whitespace-style (remove'lines-tail whitespace-style))
