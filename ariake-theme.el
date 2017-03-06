(deftheme ariake)
(let ((class '((class color) (min-colors 89)))
      (fg1 "#b9bfd4")
      (fg2 "#88cce4")
      (fg3 "#7cbad0")
      (fg4 "#70a9bc")
      (bg1 "#2a2d36")
      (bg2 "#3b3e46")
      (bg3 "#4c4f56")
      (bg4 "#5d5f66")
      (builtin "#88cce4")
      (keyword "#7c83d8")
      (const   "#daa6f2")
      (comment "#808080")
      (func    "#95ddf9")
      (str     "#9deee9")
      (type    "#7c83d8")
      (var     "#85b3dd")
      (warning "#ff00ff")
      (warning2 "#ff8800"))
  (custom-theme-set-faces
   'ariake
   `(default ((,class (:background ,bg1 :foreground ,fg1))))
   `(font-lock-builtin-face ((,class (:foreground ,builtin))))
   `(font-lock-comment-face ((,class (:foreground ,comment))))
   `(font-lock-negation-char-face ((,class (:foreground ,const))))
   `(font-lock-reference-face ((,class (:foreground ,
const))))
   `(font-lock-constant-face ((,class (:foreground ,const))))
   `(font-lock-doc-face ((,class (:foreground ,comment))))
   `(font-lock-function-name-face ((,class (:foreground ,func ))))
   `(font-lock-keyword-face ((,class (:bold ,class :foreground ,keyword))))
   `(font-lock-string-face ((,class (:foreground ,str))))
   `(font-lock-type-face ((,class (:foreground ,type ))))
   `(font-lock-variable-name-face ((,class (:foreground ,var))))
   `(font-lock-warning-face ((,class (:foreground ,warning :background ,bg2))))
   `(region ((,class (:background ,fg1 :foreground ,bg1))))
   `(highlight ((,class (:foreground ,fg3 :background ,bg3))))
   `(hl-line ((,class (:background  ,bg2))))
   `(fringe ((,class (:background ,bg2 :foreground ,fg4))))
   `(cursor ((,class (:background ,bg3))))
   `(show-paren-match-face ((,class (:background ,warning))))
   `(isearch ((,class (:bold t :foreground ,warning :background ,bg3))))))

;; ;;;###autoload
(when load-file-name
  (add-to-list 'custom-theme-load-path
               (file-name-as-directory (file-name-directory load-file-name))))

(provide-theme 'ariake)

;; Local Variables:
;; no-byte-compile: t
;; End:
