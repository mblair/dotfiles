(setq mac-command-modifier 'meta)
(setq mac-option-modifier 'super)
(setq prelude-whitespace nil)

(setq prelude-theme 'deeper-blue)

(global-linum-mode 1)
(global-set-key (kbd "M-l") 'goto-line)

(if (not (string-match "go" compile-command))
    (set (make-local-variable 'compile-command)
         "make"))
