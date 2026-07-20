;;; jinja2-ts-mode-treesit-fold.el --- Fold Jinja2 with treesit-fold -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Misaka

;;; Commentary:

;; Optional `treesit-fold' integration for `jinja2-ts-mode'.

;;; Code:

(require 'treesit)

(defvar treesit-fold-range-alist)

(defun jinja2-ts-mode-treesit-fold-range-block (node offset)
  "Return the fold range for Jinja block NODE using OFFSET."
  (let (begin end)
    (dotimes (index (treesit-node-child-count node))
      (let* ((child (treesit-node-child node index))
             (type (treesit-node-type child)))
        (when (and (not begin) (member type '("%}" "-%}" "+%}")))
          (setq begin (treesit-node-end child)))
        (when (member type '("{%" "{%-" "{%+"))
          (setq end (treesit-node-start child)))))
    (unless (and begin end)
      (let ((count (treesit-node-child-count node t)))
        (when (> count 1)
          (setq begin (treesit-node-end (treesit-node-child node 0 t)))
          (setq end (treesit-node-start
                     (treesit-node-child node (1- count) t))))))
    (when (and begin end (<= begin end))
      (cons (+ begin (car offset)) (+ end (cdr offset))))))

(setf (alist-get 'jinja2-ts-mode treesit-fold-range-alist)
      (mapcar
       (lambda (type)
         (cons type #'jinja2-ts-mode-treesit-fold-range-block))
       '(autoescape_block block_block call_block filter_block for_block
         if_block macro_block raw_block set_block trans_block with_block)))

(provide 'jinja2-ts-mode-treesit-fold)
;;; jinja2-ts-mode-treesit-fold.el ends here
