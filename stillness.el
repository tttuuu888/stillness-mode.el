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

(require 'dash)

(defgroup stillness nil
  "Make your windows jump around less by altering the point."
  :group 'stillness)

(defcustom stillness-minibuffer-height nil
  "Expected height (in lines) of the minibuffer. If set to nil, will infer from supported modes."
  :type 'integer
  :group 'stillness)

(defcustom stillness--minibuffer-point-offset 3
  "The number of lines above the minibuffer the point should be."
  :type 'integer
  :group 'stillness)

(defun stillness--minibuffer-height ()
  "Return the expected minibuffer height."
  (or stillness-minibuffer-height
    (and (bound-and-true-p vertico-mode) vertico-count)
    (and (bound-and-true-p ivy-mode) ivy-height)
    10))

(defun stillness--handle-point (read-fn &rest args)
  "Move the point and windows for a still READ-FN invocation with ARGS."
  (let ((minibuffer-count (stillness--minibuffer-height))
         (minibuffer-offset stillness--minibuffer-point-offset))
    (if (> (minibuffer-depth) 0)
      (apply read-fn args)
      (save-window-excursion
        ;; delete any windows south of where the minibuffer will be:
        (->> (window-list)
          (-filter (lambda (w)
                     (-let (((_ top _ _) (window-edges w)))
                       (< (- (frame-height) (1+ (1+ top))) minibuffer-count))))
          (-map 'delete-window))

        ;; move the point in any affected windows:
        (save-mark-and-excursion
          (->> (window-list)
            (-map (lambda (window)
                    (with-selected-window window
                      (-let* ((current-line (+ (nth 1 (window-edges)) (count-lines (window-start) (point))))
                               (minibuffer-line (- (window-total-height) minibuffer-count)))
                        (when (and (> (nth 3 (window-edges))
                                     (- (frame-height) minibuffer-count))
                                (> (1+ (1+ current-line)) minibuffer-line))
                          (deactivate-mark)
                          (move-to-window-line
                            (- minibuffer-line minibuffer-offset))))))))

          ;; tell windows to preserve themselves if they have a southern neighbor
          (-let* ((windows (--filter (window-in-direction 'below it)
                             (window-list)))
                   (_ (--map (window-preserve-size it nil t) windows))
                   (result (apply read-fn args)))
            ;; and then release those preservations
            (--map (window-preserve-size it nil nil) windows)
            result))))))

;;;###autoload
(define-minor-mode stillness-mode
  "Global minor mode to prevent windows from jumping on minibuffer activation."
  :require 'stillness
  :global t
  (if stillness-mode
    (progn
      (advice-add 'completing-read :around #'stillness--handle-point)
      (advice-add 'completing-read-multiple :around #'stillness--handle-point))
    (advice-remove 'completing-read #'stillness--handle-point)
    (advice-remove 'completing-read-multiple #'stillness--handle-point)))

(provide 'stillness)
;;; stillness.el ends here
