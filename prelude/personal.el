(setq mac-command-modifier 'meta)
(setq mac-option-modifier 'super)
(setq prelude-whitespace nil)

(global-linum-mode 1)
(global-set-key (kbd "M-l") 'goto-line)
(global-set-key "\M-c" 'clipboard-kill-ring-save)
(global-set-key "\M-v" 'clipboard-yank)
(global-set-key "\C-c c" 'comment-dwim)
(prelude-require-package 'planet-theme)
(load-theme 'planet t)
(set-face-attribute 'default nil :height 140)
;; http://sourcefoundry.org/hack/
(set-face-attribute 'default nil :family "Hack")
