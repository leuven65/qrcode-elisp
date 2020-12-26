;;; qrcode-elisp.el --- Emacs QR code generator and decoder -*- lexical-binding: t -*-

;; Author: Jian Wang <leuven65@gmail.com>
;; URL: https://github.com/leuven65/qrcode-elisp
;; Version: 0.1.0
;; Keywords: QRCode

;; This file is not part of GNU Emacs

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; For a full copy of the GNU General Public License
;; see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;

;;; Code:

(defvar qrcode-elisp-python-command
  (if (eq system-type 'windows-nt) "py" "python3")
  "python command")

(defvar qrcode-elisp-text-coding
  (if (eq system-type 'windows-nt) 'gb2312 'utf-8)
  "The coding used by qrcode encoding and decoding")

(defvar qrcode-elisp-python-package-list
  '("qrcode" "pillow" "pyzbar")
  "the Python package used by this file")

(defvar qrcode-lisp-py-code-screenshot  "
from PIL import ImageGrab
ImageGrab.grabclipboard().save('%s')
")

(defvar qrcode-elisp-py-code-qrcode-encode "
import qrcode
qr = qrcode.QRCode()
qr.add_data('''%s''')
qr.make(fit=True)
img = qr.make_image()
img.save('%s')
")

(defvar qrcode-elisp-py-code-qrcode-decode  "
from pyzbar.pyzbar import decode
from PIL import Image, ImageGrab
img_file = '%s'
img = Image.open(img_file) if img_file else ImageGrab.grabclipboard()
result = decode(img)
print(result[0].data.decode('utf-8'))
")

(defun qrcode-elisp-py-call-python (args)
  (with-temp-buffer
    (let ((py-command (format "%s %s"
                              qrcode-elisp-python-command
                              args)))
      (cons (call-process-shell-command py-command
                                        nil
                                        (current-buffer))
            (buffer-string))))
  )

(defun qrcode-elisp-py-pip-install-package (package-name)
  "use pip to install python package"
  (interactive "sPip install package: ")
  (let* ((exec-result (qrcode-elisp-py-call-python (format "-m pip install %s"
                                                           package-name)))
         (exit-code (car exec-result))
         (result-string (cdr exec-result)))
    (if (= exit-code 0)
        (progn
          (message result-string)
          result-string)
      (user-error "Failed to install python package '%s' : %s"
                  package-name
                  result-string))
    )
  )

(defun qrcode-elisp-py-exec-python-code (python-code)
  "exec python-code and return the output"
  (let* ((exec-result (qrcode-elisp-py-call-python (format "-c %s"
                                                           (shell-quote-argument python-code))))
         (exit-code (car exec-result))
         (result-string (cdr exec-result)))
    (if (= exit-code 0)
        result-string
      (user-error "Failed to exec python code '%s': %s"
                  python-code
                  result-string)))
  )

(defun qrcode-elisp-py-escape-quote-in-string (str &optional char-quote)
  (replace-regexp-in-string (or char-quote "'")
                            "\\\\'"
                            str))

(defun qrcode-elisp-py-copy-img-from-clipboard (img-file-path)
  ;; copy screenshot to file
  (delete-file img-file-path)
  (qrcode-elisp-py-exec-python-code (format qrcode-lisp-py-code-screenshot
                                  (qrcode-elisp-py-escape-quote-in-string img-file-path)))
  (unless (file-exists-p img-file-path)
    (user-error "Failed to copy screenshot")))

;;;###autoload
(defun qrcode-elisp-install-enviroment ()
  (interactive)
  (dolist (pkg qrcode-elisp-python-package-list)
    ;; check if it is installed
    (qrcode-elisp-py-pip-install-package pkg)))

(defun qrcode-elisp-generate-qrcode-to-image (text-to-qr img-file-path)
  "Generate QR code of `text-to-qr' and save the image to `img-file-paht'"
  (delete-file img-file-path)
  (qrcode-elisp-py-exec-python-code
   (format qrcode-elisp-py-code-qrcode-encode
           (qrcode-elisp-py-escape-quote-in-string text-to-qr)
           (qrcode-elisp-py-escape-quote-in-string img-file-path)))
  (if (file-exists-p img-file-path)
      (message (format "QR image file: %s" img-file-path))
    (user-error "Failed to generate QR Code")))

;;;###autoload
(defun qrcode-elisp-decode-qrcode-from-image (&optional img-file-path)
  "if img-file-path is nil, read image from clipboard"
  (interactive "f")
  (qrcode-elisp-py-exec-python-code
   (format qrcode-elisp-py-code-qrcode-decode
           (qrcode-elisp-py-escape-quote-in-string (or img-file-path "")))))

(defun qrcode-elisp-read-string (PROMPT &optional THING)
  (read-string PROMPT
               (or (when (use-region-p)
                     (buffer-substring (region-beginning) (region-end)))
                   (let ((thing (thing-at-point (or THING 'symbol) t)))
                     (when thing
                       (if (stringp thing)
                           (string-trim thing)
                         (format "%s" thing))))
                   )))

(defun qrcode-elisp-generate-tmp-image-file-name ()
  (expand-file-name (format-time-string "QR-%Y%m%d-%H%M%S-%6N.png")
                    temporary-file-directory))

(defun qrcode-elisp-generate-qr-image-file (qr-text)
  "generate QR code for the text"
  (interactive (list (qrcode-elisp-read-string "Generate QR code for: " 'sexp)))
  (let ((img-file-path (qrcode-elisp-generate-tmp-image-file-name)))
    (let ((default-process-coding-system (cons qrcode-elisp-text-coding qrcode-elisp-text-coding)))
      (qrcode-elisp-generate-qrcode-to-image qr-text img-file-path))
    img-file-path
    ))

;;;###autoload
(defun qrcode-elisp-generate-qrcode (qr-text)
  "generate QR code for the text and open the org-mode file"
  (interactive (list (qrcode-elisp-read-string "Generate QR code for: " 'sexp)))
  (let ((img-file-path (qrcode-elisp-generate-qr-image-file qr-text)))
    (view-buffer-other-window "*QR Code*"
                              nil
                              (lambda (buffer)
                                (kill-buffer buffer)
                                (delete-file img-file-path)
                                ))
    ;; Normally the local keymap will be shared between major mode, so that `local-set-key' will
    ;; take effect to other buffers in same major mode.
    ;; So that following `local-set-key' might be not buffer-local.
    (local-set-key (kbd "C-c C-o")
                   (lambda ()
                     (interactive)
                     (let ((file-path (org-element-property :path (org-element-context))))
                       (when file-path (browse-url-of-file file-path)))))
    (goto-char (point-max))
    (let ((buffer-read-only nil))
      (insert (format "* Generate QR code to %s\n" (file-name-nondirectory img-file-path))
              qr-text "\n"
              (format "[[file:%s]]\n" img-file-path))
      )
    (forward-line -2)
    (recenter 0)                        ; show it on 1st line
    (visual-line-mode +1)
    (org-display-inline-images)         ; display image in the buffer
    ))

;;;###autoload
(defun qrcode-elisp-generate-qrcode-and-open (qr-text)
  "generate QR code for the text and open the image"
  (interactive (list (qrcode-elisp-read-string "Generate QR code for: " 'sexp)))
  (let* ((img-file-path (qrcode-elisp-generate-qr-image-file qr-text)))
    (find-file-other-window img-file-path)
    ))

;;;###autoload
(defun qrcode-elisp-decode-qrcode-from-clipboard ()
  "Decode the QR Code image from clipboard"
  (interactive)
  (let* ((img-file-path (qrcode-elisp-generate-tmp-image-file-name)))
    (delete-file img-file-path)
    (qrcode-elisp-py-copy-img-from-clipboard img-file-path)
    ;; create Temporary to buffer to show result
    (view-buffer-other-window "*QR Code*"
                              nil
                              (lambda (buffer)
                                (kill-buffer buffer)
                                (delete-file img-file-path)
                                ))
    (goto-char (point-max))
    (let ((buffer-read-only nil))
      ;; show image in the buffer
      (insert (format "* Read QR code from %s\n" (file-name-nondirectory img-file-path))
              (format "[[file:%s]]\n" img-file-path))
      (insert (qrcode-elisp-decode-qrcode-from-image img-file-path) "\n")
      )
    (visual-line-mode +1)
    (org-display-inline-images)         ; display image in the buffer
    )
  )

(provide 'qrcode-elisp)

;;; qrcode-elisp.el ends here
