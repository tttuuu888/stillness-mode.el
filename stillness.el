;;; stillness.el --- Prevent windows from jumping on minibuffer activation -*- lexical-binding: t; -*-
;;
;; Author: neeasade <neeasade@users.noreply.github.com>
;; URL: https://github.com/neeasade/stillness-mode.el
;; Version: 0.1
;; Package-Requires: ((emacs "26.1") (dash "2.18.0"))
;; Keywords: convenience
;;
;; This file is not part of GNU Emacs.
;;
;;; Commentary:
;;
;; stillness-mode is a minor mode that prevents Emacs from scrolling the main
;; editing window when a multi-line minibuffer appears. It automatically adjusts
;; point just enough so that Emacs doesn't force a jump in the visible buffer.
;;
;;; Code:

(defgroup stillness nil
  "Make your windows jump around less by altering the point"
  :group 'convenience)

(defcustom stillness-minibuffer-height nil
  "Expected height (in lines) of the minibuffer. If set to nil, will infer from supported modes."
  :type 'integer
  :group 'stillness)

(defun stillness--minibuffer-height ()
  (or stillness-minibuffer-height
      (and (bound-and-true-p vertico-mode) vertico-count)
      (and (bound-and-true-p ivy-mode) ivy-height)
      10))

(defun stillness--handle-point (read-call &rest args)
  (let ((minibuffer-count (stillness--minibuffer-height))
	(minibuffer-offset 4)) 		; point adjustment above minibuffer
    (save-window-excursion
      ;; delete any windows south of where the minibuffer will be:
      (->> (window-list)
	   (-filter (lambda (w)
		      (-let (((_ top _ _) (window-edges w)))
			(> (1+ top) minibuffer-count))))
	   (-map 'delete-window))

      ;; don't resize northern neighbor:
      (when-let (north (windmove-find-other-window 'up))
	;; NB: save-window-excursion does not undo this 😩
	(window-preserve-size north nil t))

      ;; move the point in any affected windows:
      (save-mark-and-excursion
	(->> (window-list)
	     (-map (lambda (window)
		     (with-selected-window window
		       (-let ((frame-line (+ (nth 1 (window-edges))
					     (count-lines (window-start) (point)))))
			 (when (> frame-line (- minibuffer-count minibuffer-offset))
			   (deactivate-mark)
			   (move-to-window-line
			    (- minibuffer-count minibuffer-offset (nth 1 (window-edges))))))))))

	;; do the thing:
	(apply read-call args)))))

(define-minor-mode stillness-mode
    "Global minor mode to prevent windows from jumping on minibuffer activation."
  :global t
  (if stillness-mode
      (advice-add 'completing-read :around #'stillness--handle-point)
    (advice-remove 'completing-read #'stillness--handle-point)))

(provide 'stillness)
;;; stillness.el ends here
