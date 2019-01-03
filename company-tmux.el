;;; company-tmux.el --- auto complete with content of tmux panes -*- lexical-binding: t -*-

;; Copyright (C) 2019 by Jörg Thalheim
;; Copyright (C) 2017 by Syohei YOSHIDA

;; Author: Syohei YOSHIDA <syohex@gmail.com>
;; URL: https://github.com/Mic92/company-tmux
;; Version: 0.01
;; Package-Requires: ((emacs "24.3") (company "0.9.9"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;;; Code:

(require 'cl-lib)
(require 'company)

(defsubst company-tmux--in-tmux-p ()
  (or (getenv "TMUX") (getenv "TMUX_PANE")))

(cl-defstruct (tmux-pane) session-id id pane-active window-active)

(defun company-tmux--parse-fields (line)
  (let ((fields (split-string line " " t)))
    (destructuring-bind (session-id pane-id pane-active window-active) fields
        (make-tmux-pane :id pane-id
                        :session-id session-id
                        :pane-active pane-active
                        :window-active window-active))))

(defun company-tmux--collect-panes ()
  (with-temp-buffer
    (unless (zerop (call-process "tmux" nil t nil "list-panes" "-a" "-F" "#{session_id} #{pane_id} #{pane_active} #{window_active}"
))
      (error "Failed: 'tmux list-panes -F #P"))
    (let* ((lines (split-string (buffer-string) "\n" t))
           (panes (mapcar 'company-tmux--parse-fields lines)))
    (reverse panes))))

(defun company-tmux--trim (str)
  (let ((left-trimed (if (string-match "\\`[ \t\n\r]+" str)
                         (replace-match "" t t str)
                       str)))
    (if (string-match "[ \t\n\r]+\\'" left-trimed)
        (replace-match "" t t left-trimed)
      left-trimed)))

(defun company-tmux--split-line (line)
  (unless (string-match-p "\\`\\s-*\\'" line)
    (mapcar 'company-tmux--trim (append (split-string line)
                                            (split-string line "[^a-zA-Z0-9_]+")))))

(defun company-tmux--remove-space-candidates (candidates)
  (cl-remove-if (lambda (c) (string-match-p "\\`\\s-*\\'" c)) candidates))

(defun company-tmux--parse-capture-output ()
  (goto-char (point-min))
  (let ((candidates nil))
    (while (not (eobp))
      (let* ((line (buffer-substring-no-properties
                    (line-beginning-position) (line-end-position)))
             (words (company-tmux--split-line line)))
        (when words
          (setq candidates (append words candidates)))
        (forward-line 1)))
    candidates))

(defun company-tmux--capture-pane (pane)
  (with-temp-buffer
    (unless (zerop (call-process "tmux" nil t nil
                                 "capture-pane" "-J" "-p" "-t" (tmux-pane-id pane)))
      (error "Failed: 'tmux capture-pane -J -p -t %s'" (tmux-pane-id pane)))
    (let* ((candidates (company-tmux--parse-capture-output))
           (sorted (sort candidates 'string<)))
      (cl-delete-duplicates sorted :test 'equal)
      (company-tmux--remove-space-candidates sorted))))

(defun company-tmux--collect-candidates (panes)
  (cl-loop for pane in panes
           unless (and
                    (string-equal (tmux-pane-window-active pane) (tmux-pane-pane-active pane))
                    (string-equal (tmux-pane-session-id pane) (company-tmux--current-session)))
           append (company-tmux--capture-pane pane)))

(defun company-tmux--filter-candidates (prefix candidates)
  (cl-loop with regexp = (format "\\`%s." prefix)
           for candidate in candidates
           when (string-match-p regexp candidate)
           collect candidate))

(defun company-tmux--current-session()
  (with-temp-buffer
    (unless (zerop (call-process "tmux" nil t nil
                                 "display-message" "-p" "#{session_id}"))
      (error "Failed: 'tmux display-message -p #{session_id}"))
    (company-tmux--trim (buffer-string))))

(defun company-tmux--candidates (prefix)
  (unless (company-tmux--in-tmux-p)
    (error "Not running inside tmux!!"))
  (let* ((candidates (company-tmux--collect-candidates
                      (company-tmux--collect-panes)))
         (filtered (company-tmux--filter-candidates prefix candidates)))
    filtered))

;;;###autoload
(defun company-tmux (command &optional arg &rest ignored)
  (interactive (list 'interactive))
  (message arg)
  (cl-case command
    (interactive (company-begin-backend 'company-tmux-backend))
    (prefix (company-grab-symbol))
    (candidates (company-tmux--candidates arg))))

;;;###autoload
(defun company-tmux-setup ()
  "Add `company-tmux-backend' to `company-sources'"
  (interactive)
  (add-to-list 'company-backends 'company-tmux))

(provide 'company-tmux)

;;; company-tmux.el ends here
