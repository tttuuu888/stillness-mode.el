;;; stillness-mode.el --- Prevent windows from jumping on minibuffer activation -*- lexical-binding: t; -*-
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

(defgroup stillness-mode nil
  "Make your windows jump around less by altering the point and window layout."
  :prefix "stillness-mode"
  :group 'stillness)

(defcustom stillness-mode-minibuffer-height nil
  "Expected height (in lines) of the minibuffer.

If set to nil, will infer from supported modes."
  :type 'integer
  :group 'stillness)

(defcustom stillness-mode--minibuffer-point-offset 3
  "The number of lines above the minibuffer the point should be."
  :type 'integer
  :group 'stillness)

(defun stillness-mode--minibuffer-height ()
  "Return the expected minibuffer height."
  (or stillness-mode-minibuffer-height
    (and (bound-and-true-p vertico-mode) vertico-count)
    (and (bound-and-true-p ivy-mode) ivy-height)
    10))

(defun stillness-mode--handle-point (read-fn &rest args)
  "Move the point and windows for a still READ-FN invocation with ARGS."
  (let ((minibuffer-count (stillness-mode--minibuffer-height))
         (minibuffer-offset stillness-mode--minibuffer-point-offset))
    (if (or (> (minibuffer-depth) 0)
          (> minibuffer-count (frame-height))) ; pebkac: should we message if this is the case?
      (apply read-fn args)
      (save-window-excursion
        ;; delete any windows south of where the minibuffer will be:
        (->> (window-list)
          (-filter (lambda (w)
                     (-let (((_ top _ _) (window-edges w)))
                       (< (- (frame-height) (1+ (1+ top))) minibuffer-count))))
          (mapc #'delete-window))

        ;; move the point in any affected windows:
        (save-mark-and-excursion
          (-each (window-list)
            (lambda (window)
              (with-selected-window window
                (-let* ((current-line (+ (nth 1 (window-edges)) (count-lines (window-start) (point))))
                         (minibuffer-line (- (window-total-height) minibuffer-count))
                         (col (current-column)))
                  (when (and (> (nth 3 (window-edges))
                               (- (frame-height) minibuffer-count))
                          (> (1+ (1+ current-line)) minibuffer-line))
                    (deactivate-mark)
                    (move-to-window-line (- minibuffer-line minibuffer-offset))
                    (move-to-column col))))))

          ;; tell windows to preserve themselves if they have a southern neighbor
          (-let* ((windows (--filter (window-in-direction 'below it)
                             (window-list)))
                   (_ (--each windows (window-preserve-size it nil t)))
                   (result (apply read-fn args)))
            ;; and then release those preservations
            (--each windows (window-preserve-size it nil nil))
            result))))))

;;;###autoload
(define-minor-mode stillness-mode
  "Global minor mode to prevent windows from jumping on minibuffer activation."
  :require 'stillness-mode
  :global t
  (if stillness-mode
    (progn
      (advice-add 'completing-read :around #'stillness-mode--handle-point '(depth 90))
      (advice-add 'completing-read-multiple :around #'stillness-mode--handle-point '(depth 90)))
    (advice-remove 'completing-read #'stillness-mode--handle-point)
    (advice-remove 'completing-read-multiple #'stillness-mode--handle-point)))

(provide 'stillness-mode)
;;; stillness-mode.el ends here
