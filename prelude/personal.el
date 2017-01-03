(setq mac-command-modifier 'meta)
(setq mac-option-modifier 'super)
(setq prelude-whitespace nil)
(global-linum-mode 1)
(global-set-key (kbd "M-l") 'goto-line)
(global-set-key "\C-c c" 'comment-dwim)
(prelude-require-package 'majapahit-theme)
(prelude-require-package 'ag)
(load-theme 'majapahit-dark t)
(set-face-attribute 'default nil :height 140)
(set-face-attribute 'default nil :family "Hack")
(setq whitespace-style (remove'lines-tail whitespace-style))
