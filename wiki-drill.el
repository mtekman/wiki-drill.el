;;; wiki-drill.el --- Generate org-drill cards from wikipedia summaries -*- lexical-binding: t; -*-

;; Copright (C) 2018 Mehmet Tekman <mtekman89@gmail.com>

;; Author: Mehmet Tekman
;; URL: https://github.com/mtekman/wiki-drill.el
;; Keywords: outlines
;; Package-Requires: ((emacs "24") (wiki-summary "0"))
;; Version: 0.1

;;; Commentary:

;; Often when one skims over a wikipedia article, the information remembered in
;; the short time span is not preserved.  This package uses Danny Gratzer's
;; excellent wiki-summary tool and converts the output into drill format.

;; To use this package, simply call M-x wiki-drill (or bind it to a key).
;; This will prompt you for an article title to search, where you can then
;; specify a wikipedia topic of choice, as well as a flashcard clozer type
;; (as given by org-drill options).  A new buffer window will present itself
;; with the summary for that wikipiedia article, and instructions on how to
;; mark the text that you wish to obscure will appear in the comments in the
;; buffer.  Once you have completed marking the text, you can then submit
;; your changes which will be refiled into the wiki-drill-file of your choice

(require 'wiki-summary)

;;; Code:

(defvar wiki-drill--tmp-subject
  "Temporary subject passed between make-flash and clozer-submit methods"
  nil)
(defvar wiki-drill--tmp-type
  "Temporary flashcard type passed between make-flash and clozer-submit methods"
  nil)

;; --- File operations
(defcustom wiki-drill-file "~/wiki-drill-inputs.org"
  "File to temprarily store drill entries, where it is then up to the user to refile these entries."
  :type 'string)

(defcustom wiki-drill--binding-clozer-mark "C-b"
  "Binding to mark words or phrases in clozer minor mode."
  :type 'string)

(defcustom wiki-drill--binding-submit "C-c C-c"
  "Binding to submit flashcard."
  :type 'string)

(defcustom wiki-drill-custom-clozer '()
  "A list of custom clozer types provided by the user."
  :type 'array)


;; -- FlashCard buffer
(defvar wiki-drill--flashcardbuffer "*FlashCard*"
  "Buffer name for flashcard.")

(defun wiki-drill-get-flashcard-buffer ()
  "Generate (and create) the flashcard buffer."
  (get-buffer-create wiki-drill--flashcardbuffer))


;; --- Clozer Flashcard Functions

(defun wiki-drill-offer-flashcard-choices ()
  "Offer a choice of categories to the user."
  (let ((choices
         (append
          '("simple"
            "hide1cloze"      ;; hides 1 at random, shows all others
            "show1cloze"      ;; shows 1 at random, hides all others
            "hide2cloze"      ;; hides 2 at random, shows all others
            "show2cloze"      ;; shows 2 at random, hides all others
            "hide1_firstmore" ;; hides 1st 75% of the time, shows all others
            "show1_firstless" ;; shows 1st 25% of the time, hides all others
            "show1_lastmore") ;; shows last 75% of the time, hides all others
          wiki-drill-custom-clozer)))
    (progn (sit-for 1)
           (select-frame-set-input-focus (window-frame (active-minibuffer-window)))
           (completing-read "Clozer Types: " choices))))

(defun wiki-drill-make-flash-clozer-usertext ()
  "Pull text from 'wiki-summary' into FlashCard, let the user mark words."
  (let* ((flashbuff (wiki-drill-get-flashcard-buffer)))
    (sit-for 0.1)
    (with-current-buffer "*wiki-summary*"
      (setq inhibit-read-only t)
      (let ((comment-str
             (concat ";; Mark keywords or regions with brackets ("
                     wiki-drill--binding-clozer-mark
                     "), and leave hints with\n;; bars, submit with ("
                     wiki-drill--binding-submit
                     ")   e.g. [hide these words||drop this hint]\n\n")))
        (put-text-property 0 (length comment-str) 'face 'font-lock-comment-face comment-str)
        (insert comment-str)
        (progn (buffer-swap-text flashbuff)      ;; switch text to that of flashcard
               (pop-to-buffer flashbuff)
               (wiki-drill-clozer-mode 1))))))

(defun wiki-drill-make-flash (subject)
  "Offer the user flashcard for SUBJECT of choice."
  (let* ((flash-type (wiki-drill-offer-flashcard-choices)))
    (setq wiki-drill--tmp-subject subject)
    (setq wiki-drill--tmp-type flash-type)
    (wiki-drill-make-flash-clozer-usertext)))


;; --- Clozer Mode Functions --
(defun wiki-drill-clozer-brackets ()
  "Surrounds with [[words||hint]]."
  (interactive)
  (let (pos1 pos2 bds)
    (if (use-region-p)
        (setq pos1 (region-beginning) pos2 (region-end))
      (
        (setq bds (bounds-of-thing-at-point 'symbol))
        (setq pos1 (car bds) pos2 (cdr bds))))
    (goto-char pos2) (insert "||<hint>]")
    (goto-char pos1) (insert "[")
    (goto-char (+ pos2 4))))

(define-minor-mode wiki-drill-clozer-mode
  "Toggles clozer bracketing mode."
  :init-value nil
  :lighter " clozer"
  :keymap (let ((map (make-sparse-keymap)))
            (define-key map (kbd wiki-drill--binding-clozer-mark)
              (lambda () (wiki-drill-clozer-brackets)))
            (define-key map (kbd wiki-drill--binding-submit)
              (lambda () (wiki-drill-clozer-submit)))
            map))

;; --- Submitting a flashcard
(defun wiki-drill-refile-into-file (text)
  "Refile TEXT into inbox file."
  (if (not (file-exists-p wiki-drill-file))
      (write-region "" nil wiki-drill-file))
  (write-region text nil wiki-drill-file 'append))

(defun wiki-drill-total-text (subject type body)
  "Place the BODY and TYPE under the SUBJECT."
  (format "\
* %s     :drill:
   :PROPERTIES:
   :DRILL_CARD_TYPE: %s
   :END:

** Definition:
%s
" subject type body))

(defun wiki-drill-get-flashcard-text ()
  "Get non-commented text from FlashCard buffer."
  (with-current-buffer (wiki-drill-get-flashcard-buffer)
    (save-restriction
      (widen)
      (goto-char (point-min))
      (buffer-substring-no-properties
       (search-forward-regexp "^[^;$]")
       (point-max)))))

(defun wiki-drill-kill-all-buffers ()
  "Kill buffers related to 'wiki-summary' and FlashCard."
  (when (get-buffer "*wiki-summary*") (kill-buffer "*wiki-summary*"))
  (when (get-buffer "*FlashCard*" ) (kill-buffer "*FlashCard*")))

(defun wiki-drill-clozer-submit ()
  "Pulls text from Flashcard buffer and then call the refiler."
  (interactive)
  (let* ((user-text (wiki-drill-get-flashcard-text))
         (total-text (wiki-drill-total-text
                      wiki-drill--tmp-subject
                      wiki-drill--tmp-type
                      user-text)))
    (progn (wiki-drill-refile-into-file total-text)
           (wiki-drill-kill-all-buffers)
           (switch-to-buffer (find-file wiki-drill-file)))))

;;;###autoload
(defun wiki-drill (subject)
  "Generate 'org-drill' notes from 'wiki-summary' SUBJECT snippets."
  (interactive)
  (wiki-summary subject)
  (wiki-drill-kill-all-buffers)
  (wiki-drill-make-flash subject))

(provide 'wiki-drill)

;; -- Tests --
;; (wiki-drill "Lawton railway station")
;; (wiki-drill "RNA")

;;; wiki-drill.el ends here
