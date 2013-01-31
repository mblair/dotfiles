(deftheme telstar
	"A port of [telstar](https://github.com/vim-scripts/telstar.vim) from Vim to Emacs.")

(let (
			;; Palette
			(background "#000022")
			(foreground "#5060c0"))

  (custom-theme-set-faces
   'telstar

	 `(default ((t (:foreground, foreground :background, background))))
	 `(cursor  ((t (:background, "#b8b8b8"))))
	 `(region  ((t (:foreground, "#ffffff" :background, foreground))))
	 ;; (border-color . "#000000")
	 `(fringe ((t (:background, background))))
	 `(mode-line ((t (:foreground "#000000" :background "#a1a2a0"))))
	 `(minibuffer-prompt ((t (:foreground "#729fcf" :bold t))))

	 `(font-lock-builtin-face ((t (:foreground "#9060c8"))))
	 `(font-lock-keyword-face ((t (:foreground "#9060c8"))))
	 `(font-lock-function-name-face ((t (:foreground "#9060c8"))))
	 `(font-lock-type-face ((t (:foreground "#9060c8"))))

	 `(font-lock-comment-face ((t (:foreground "#604060"))))

	 `(font-lock-string-face ((t (:foreground "#999999"))))
	 `(font-lock-constant-face ((t (:foreground "#85a1ef"))))
	 `(font-lock-variable-name-face ((t (:foreground "#eeeeec"))))
	 `(font-lock-warning-face ((t (:foreground "red" :bold t))))))

(provide-theme 'telstar)
