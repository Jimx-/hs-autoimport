;;; hs-autoimport.el --- Add missing imports for Haskell source files for the identifier at point  -*- lexical-binding: t; -*-

;; Copyright (C) 2018 Jin Xue

;; Author: Jin Xue <csjinxue@outlook.com>
;; URL: https://github.com/Jimx-/hs-autoimport
;; Created: 29 Dec 2018
;; Keywords: Haskell
;; Package-Requires: (thingatpt cl-lib seq)

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
;; This package automatically add missing import statements for Haskell
;; source files for the identifier at point.
;;
;; It finds the modules with the target symbol on Hoogle and displays a
;; list of all candidate modules.  An import statement is added to the
;; source file after user selects a module from the candidate list.
;;
;; Installation:
;; In `init.el`,
;; (add-to-list 'load-path "/path/to/hs-autoimport")
;; (require 'hs-autoimport)
;;

;;; Code:

(require 'thingatpt)
(require 'cl-lib)
(require 'seq)

(defun hs-autoimport-import-module ()
  "Import the whole module for the identifier at point or in the region."
  (interactive)
  (hs-autoimport--lookup-module (hs-autoimport--get-identifier) t))

(defun hs-autoimport-import-symbol ()
  "Import only the identifier at point or in the region."
  (interactive)
  (hs-autoimport--lookup-module (hs-autoimport--get-identifier) nil))

(defun hs-autoimport--get-identifier ()
  (if (use-region-p)
      (buffer-substring-no-properties (region-beginning) (region-end))
    (thing-at-point 'symbol)))

(defun hs-autoimport--build-hoogle-url (identifier)
  (format "https://hoogle.haskell.org/?hoogle=%s&scope=set%%3Astackage&mode=json" identifier))

(defun hs-autoimport--lookup-module (identifier import-module)
  "Lookup modules with IDENTIFIER on Hoogle and add the import statement for the module."
  (if (string-equal identifier "")
      (message "No identifier at point")
    (url-retrieve
     (hs-autoimport--build-hoogle-url identifier)
     'hs-autoimport--hoogle-retrieve-callback
     (list identifier import-module (current-buffer)))))

(defun hs-autoimport--hoogle-retrieve-callback (&optional redirect identifier import-module buffer)
  (when (not (string-match "200 OK" (buffer-string)))
    (error "Problem connecting to Hoogle"))

  (re-search-forward "^$" nil 'move)

  (let* ((json (cl-remove-if
                (lambda (result)
                  (string-equal "" (assoc-default 'name (assoc-default 'package result))))
                (json-read-from-string (buffer-substring-no-properties (point) (point-max)))))

         (results (mapcar
                   (lambda (result)
                     (list
                      (assoc-default 'name (assoc-default 'package result))
                      (assoc-default 'name (assoc-default 'module result))
                      (hs-autoimport--parse-item (assoc-default 'item result))))
                   json))
         (choices (mapcar (lambda (result)
                            (concat (propertize (elt result 1) 'face 'bold)
                                    "("
                                    (elt result 0)
                                    ") "
                                    (propertize (elt result 2) 'face '('italic :foreground "gray"))))
                          results))
         (choice (completing-read (format "Select a module to import:")
                                  choices
                                  nil
                                  t))
         (choice-index (cl-position choice choices :test 'equal)))
    (apply 'hs-autoimport--add-import (append (list identifier import-module buffer) (elt results choice-index)))))

(defun hs-autoimport--parse-item (item)
  "Parse the ITEM returned by Hoogle."
  (let ((dom
         (with-temp-buffer
           (insert item)
           (libxml-parse-html-region (point-min) (point-max)))))
    (hs-autoimport--extract-dom-text dom)))

(defun hs-autoimport--extract-dom-text (dom)
  (if (listp dom)
      (apply 'concat (mapcar 'hs-autoimport--extract-dom-text (seq-drop dom 2)))
    dom))

(defun hs-autoimport--add-import (identifier import-module buffer package module item)
  (with-current-buffer buffer
    (save-excursion
      (goto-char (point-max))
      (if (re-search-backward "^import" nil t)
        (forward-line 1)
        (goto-char (point-min))
        (if (re-search-forward "where$" nil t)
            (forward-line 1)
          (goto-char (point-min))))

      (insert (format "import %s" module))
      (unless import-module
        (insert (format " (%s)" identifier)))
      (insert "\n"))))

(provide 'hs-autoimport)
