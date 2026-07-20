;;; jinja2-ts-mode-test.el --- Tests for jinja2-ts-mode -*- lexical-binding: t; -*-

;;; Code:

(require 'ert)
(require 'jinja2-ts-mode)
(eval-and-compile
  (defvar treesit-fold-range-alist nil))
(require 'jinja2-ts-mode-treesit-fold)

(defun jinja2-ts-mode-test--face-at (text)
  "Return the face on the final character of TEXT in the current buffer."
  (goto-char (point-min))
  (search-forward text)
  (get-text-property (1- (point)) 'face))

(ert-deftest jinja2-ts-mode-registers-template-file-patterns ()
  (let ((pattern (car (rassq 'jinja2-ts-mode auto-mode-alist))))
    (should (string-match-p pattern "template.j2"))
    (should (string-match-p pattern "template.jinja"))
    (should (string-match-p pattern "template.jinja2"))))

(ert-deftest jinja2-ts-mode-registers-grammar-source ()
  (should (equal (alist-get 'jinja treesit-language-source-alist)
                 jinja2-ts-mode-grammar-source))
  (cl-letf (((symbol-function 'treesit-install-language-grammar)
             (lambda (language) language)))
    (should (eq (jinja2-ts-mode-install-grammar) 'jinja))))

(ert-deftest jinja2-ts-mode-customizes-grammar-source-for-installation ()
  (let ((original-source jinja2-ts-mode-grammar-source)
        (custom-source '("https://example.invalid/tree-sitter-jinja"
                         "verified-revision"
                         "grammar/src"))
        installed-source)
    (unwind-protect
        (progn
          (setopt jinja2-ts-mode-grammar-source custom-source)
          (cl-letf (((symbol-function 'treesit-install-language-grammar)
                     (lambda (language &rest _)
                       (setq installed-source
                             (alist-get language
                                        treesit-language-source-alist)))))
            (jinja2-ts-mode-install-grammar))
          (should (equal installed-source custom-source)))
      (setopt jinja2-ts-mode-grammar-source original-source))))

(ert-deftest jinja2-ts-mode-installs-grammar-source-set-with-setq ()
  (let ((original-source jinja2-ts-mode-grammar-source)
        (original-registered-source
         (alist-get 'jinja treesit-language-source-alist))
        (custom-source '("https://example.invalid/tree-sitter-jinja"
                         "setq-revision"
                         "grammar/src"))
        installed-source)
    (unwind-protect
        (progn
          (setq jinja2-ts-mode-grammar-source custom-source)
          (cl-letf (((symbol-function 'treesit-install-language-grammar)
                     (lambda (language &rest _)
                       (setq installed-source
                             (alist-get language
                                        treesit-language-source-alist)))))
            (jinja2-ts-mode-install-grammar))
          (should (equal installed-source custom-source)))
      (setq jinja2-ts-mode-grammar-source original-source)
      (setf (alist-get 'jinja treesit-language-source-alist)
            original-registered-source))))

(ert-deftest jinja2-ts-mode-activates-without-installed-grammar ()
  (with-temp-buffer
    (cl-letf (((symbol-function 'treesit-ready-p) (lambda (&rest _) nil)))
      (jinja2-ts-mode))
    (should (eq major-mode 'jinja2-ts-mode))
    (should (equal comment-start "{# "))))

(ert-deftest jinja2-ts-mode-parses-representative-template ()
  (skip-unless (treesit-ready-p 'jinja))
  (with-temp-buffer
    (insert "{% macro card(title) %}\n"
            "{% if title is defined %}{{ title|upper }}{% else %}none{% endif %}\n"
            "{% endmacro %}")
    (jinja2-ts-mode)
    (let ((root (treesit-buffer-root-node 'jinja)))
      (should (equal (treesit-node-type root) "source"))
      (should-not (treesit-search-subtree root "ERROR")))))

(ert-deftest jinja2-ts-mode-finds-definition-names ()
  (skip-unless (treesit-ready-p 'jinja))
  (with-temp-buffer
    (insert "{% macro card(title) %}{{ title }}{% endmacro %}\n"
            "{% block content %}body{% endblock %}")
    (jinja2-ts-mode)
    (let ((root (treesit-buffer-root-node 'jinja)))
      (should (equal (jinja2-ts-mode--defun-name
                      (treesit-search-subtree root "macro_block"))
                     "card"))
      (should (equal (jinja2-ts-mode--defun-name
                      (treesit-search-subtree root "block_block"))
                     "content")))))

(ert-deftest jinja2-ts-mode-indents-nested-blocks ()
  (skip-unless (treesit-ready-p 'jinja))
  (with-temp-buffer
    (insert "{% if enabled %}\n"
            "value\n"
            "{% for item in items %}\n"
            "{{ item }}\n"
            "{% else %}\n"
            "empty\n"
            "{% endfor %}\n"
            "{% endif %}")
    (jinja2-ts-mode)
    (indent-region (point-min) (point-max))
    (should
     (equal (buffer-string)
            (concat "{% if enabled %}\n"
                    "  value\n"
                    "  {% for item in items %}\n"
                    "    {{ item }}\n"
                    "  {% else %}\n"
                    "    empty\n"
                    "  {% endfor %}\n"
                    "{% endif %}")))))

(ert-deftest jinja2-ts-mode-fontifies-semantic-nodes ()
  (skip-unless (treesit-ready-p 'jinja))
  (let ((treesit-font-lock-level 4))
    (with-temp-buffer
      (insert "{% macro card(title) %}{{ render(title, 42) }}{% endmacro %}")
      (jinja2-ts-mode)
      (font-lock-ensure)
      (should (eq (jinja2-ts-mode-test--face-at "macro")
                  'font-lock-keyword-face))
      (should (eq (jinja2-ts-mode-test--face-at "card")
                  'font-lock-function-name-face))
      (should (eq (jinja2-ts-mode-test--face-at "render")
                  'font-lock-function-call-face))
      (should (eq (jinja2-ts-mode-test--face-at "42")
                  'font-lock-number-face))
      (should (eq (jinja2-ts-mode-test--face-at "endmacro")
                  'font-lock-keyword-face)))))

(ert-deftest jinja2-ts-mode-fontifies-narrowed-indirect-buffer ()
  (skip-unless (treesit-ready-p 'jinja))
  (let ((treesit-font-lock-level 4))
    (with-temp-buffer
      (insert "host{% if enabled %}{{ render(value) }}{% endif %}host")
      (let ((indirect (clone-indirect-buffer " *jinja2-indirect*" nil)))
        (unwind-protect
            (with-current-buffer indirect
              (narrow-to-region 5 (- (point-max) 4))
              (jinja2-ts-mode)
              (font-lock-ensure)
              (should (eq (jinja2-ts-mode-test--face-at "if")
                          'font-lock-keyword-face))
              (should (eq (jinja2-ts-mode-test--face-at "render")
                          'font-lock-function-call-face))
              (dotimes (offset (- (point-max) (point-min)))
                (should-not
                 (eq (get-text-property (+ (point-min) offset) 'face)
                     'font-lock-warning-face))))
          (kill-buffer indirect))))))

(ert-deftest jinja2-ts-mode-registers-treesit-fold-ranges ()
  (let ((ranges (alist-get 'jinja2-ts-mode treesit-fold-range-alist)))
    (dolist (type '(autoescape_block block_block call_block filter_block
                    for_block if_block macro_block raw_block set_block
                    trans_block with_block))
      (should (eq (alist-get type ranges)
                  #'jinja2-ts-mode-treesit-fold-range-block)))))

(ert-deftest jinja2-ts-mode-computes-treesit-fold-range ()
  (skip-unless (treesit-ready-p 'jinja))
  (with-temp-buffer
    (insert "{% if enabled %}\nbody\n{% endif %}")
    (jinja2-ts-mode)
    (let* ((node (treesit-search-subtree
                  (treesit-buffer-root-node 'jinja) "if_block"))
           (range (jinja2-ts-mode-treesit-fold-range-block
                   node '(0 . 0))))
      (should (equal (buffer-substring-no-properties
                      (car range) (cdr range))
                     "\nbody\n")))))

(provide 'jinja2-ts-mode-test)
;;; jinja2-ts-mode-test.el ends here
