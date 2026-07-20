;;; jinja2-ts-mode.el --- Tree-sitter mode for Jinja templates -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Misaka

;; Author: Misaka <chuxubank@qq.com>
;; Maintainer: Misaka <chuxubank@qq.com>
;; Version: 0.1.2
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, templates, jinja2, tree-sitter
;; URL: https://github.com/chuxubank/jinja2-ts-mode

;;; Commentary:

;; A tree-sitter major mode for Jinja and Jinja2 templates.  It uses the
;; `jinja' grammar from https://github.com/cathaysia/tree-sitter-jinja.
;;
;; Install the grammar with:
;;
;;   M-x jinja2-ts-mode-install-grammar

;;; Code:

(require 'treesit)

(defgroup jinja2-ts nil
  "Major mode for Jinja templates, powered by tree-sitter."
  :group 'languages
  :prefix "jinja2-ts-mode-")

(defcustom jinja2-ts-mode-indent-offset 2
  "Number of spaces for each Jinja block indentation step."
  :type 'integer
  :safe #'integerp
  :group 'jinja2-ts)

(defun jinja2-ts-mode--set-grammar-source (symbol source)
  "Set SYMBOL to SOURCE and register it for the `jinja' grammar."
  (set-default symbol source)
  (setf (alist-get 'jinja treesit-language-source-alist) source))

(defcustom jinja2-ts-mode-grammar-source
  '("https://github.com/cathaysia/tree-sitter-jinja"
    "v0.13.0"
    "tree-sitter-jinja/src")
  "Source used to install the `jinja' tree-sitter grammar.
The value has the same form as the cdr of an entry in
`treesit-language-source-alist'."
  :type '(repeat string)
  :set #'jinja2-ts-mode--set-grammar-source
  :group 'jinja2-ts)

(defvar jinja2-ts-mode--syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?_ "w" table)
    (modify-syntax-entry ?' "\"" table)
    table)
  "Syntax table for `jinja2-ts-mode'.")

(defconst jinja2-ts-mode--block-node-types
  '("autoescape_block" "block_block" "call_block" "filter_block"
    "for_block" "if_block" "macro_block" "set_block" "trans_block"
    "with_block")
  "Jinja syntax nodes whose bodies add one indentation level.")

(defun jinja2-ts-mode--closing-statement-p (_node _parent bol)
  "Return non-nil if a closing Jinja statement begins at BOL."
  (save-excursion
    (goto-char bol)
    (back-to-indentation)
    (looking-at-p
     (concat "{%[+-]?[[:space:]]*"
             "\\(?:el\\(?:if\\|se\\)\\|pluralize\\|"
             "end\\(?:autoescape\\|block\\|call\\|filter\\|for\\|"
             "if\\|macro\\|set\\|trans\\|with\\)\\)\\_>"))))

(defun jinja2-ts-mode--indent-depth (_node parent bol)
  "Return indentation implied by PARENT at BOL."
  (let ((depth 0))
    (while parent
      (when (and (member (treesit-node-type parent)
                         jinja2-ts-mode--block-node-types)
                 (< (treesit-node-start parent) bol))
        (setq depth (1+ depth)))
      (setq parent (treesit-node-parent parent)))
    (* depth jinja2-ts-mode-indent-offset)))

(defun jinja2-ts-mode--closing-indent-depth (node parent bol)
  "Return indentation for closing statement NODE with PARENT at BOL."
  (max 0 (- (jinja2-ts-mode--indent-depth node parent bol)
            jinja2-ts-mode-indent-offset)))

(defvar jinja2-ts-mode--indent-rules
  `((jinja
     ((parent-is "source") column-0 0)
     (jinja2-ts-mode--closing-statement-p
      column-0 jinja2-ts-mode--closing-indent-depth)
     (catch-all column-0 jinja2-ts-mode--indent-depth)
     (no-node parent-bol 0)))
  "Tree-sitter indentation rules for `jinja2-ts-mode'.")

(defvar jinja2-ts-mode--font-lock-settings
  (treesit-font-lock-rules
   :language 'jinja
   :feature 'comment
   :override t
   '((comment) @font-lock-comment-face)

   :language 'jinja
   :feature 'definition
   :override t
   '((macro_statement
      (function_call (identifier) @font-lock-function-name-face))
     (block_statement (identifier) @font-lock-function-name-face)
     (for_statement
      (in_expression (identifier) @font-lock-variable-name-face))
     (set_statement
      (expression
       (binary_expression
        (unary_expression
         (primary_expression
          (identifier) @font-lock-variable-name-face))))))

   :language 'jinja
   :feature 'keyword
   :override t
   '(["autoescape" "as" "block" "break" "call" "continue" "debug"
      "do" "else" "elif" "endautoescape" "endblock" "endcall"
      "endfilter" "endfor" "endif" "endmacro" "endset" "endtrans"
      "endwith" "extends" "filter" "for" "from" "if" "import"
      "include" "in" "macro" "pluralize" "required" "set" "trans"
      "with"] @font-lock-keyword-face
     [(raw_start) (raw_end)] @font-lock-keyword-face)

   :language 'jinja
   :feature 'string
   :override t
   '((string_literal) @font-lock-string-face)

   :language 'jinja
   :feature 'constant
   :override t
   '([(boolean_literal) (null_literal)] @font-lock-constant-face)

   :language 'jinja
   :feature 'number
   :override t
   '([(number_literal) (float_literal)] @font-lock-number-face)

   :language 'jinja
   :feature 'function
   :override 'keep
   '((function_call (identifier) @font-lock-function-call-face)
     (call_statement (identifier) @font-lock-function-call-face)
     (inline_trans "_" @font-lock-builtin-face))

   :language 'jinja
   :feature 'variable
   :override 'keep
   '((identifier) @font-lock-variable-use-face)

   :language 'jinja
   :feature 'operator
   :override t
   '([(binary_operator) (unary_operator) (builtin_test)]
     @font-lock-operator-face)

   :language 'jinja
   :feature 'bracket
   :override t
   '(["(" ")" "[" "]" "<" ">"] @font-lock-bracket-face)

   :language 'jinja
   :feature 'delimiter
   :override t
   '(["{{" "{{-" "{{+" "}}" "-}}" "+}}"
      "{%" "{%-" "{%+" "%}" "-%}" "+%}"] @font-lock-preprocessor-face
     ["," "." ":"] @font-lock-delimiter-face))
  "Tree-sitter font-lock settings for `jinja2-ts-mode'.")

(defun jinja2-ts-mode--defun-name (node)
  "Return the macro or block name declared by NODE."
  (when-let ((identifier (treesit-search-subtree node "identifier")))
    (treesit-node-text identifier t)))

;;;###autoload
(defun jinja2-ts-mode-install-grammar ()
  "Install or update the `jinja' tree-sitter grammar."
  (interactive)
  (setf (alist-get 'jinja treesit-language-source-alist)
        jinja2-ts-mode-grammar-source)
  (treesit-install-language-grammar 'jinja))

;;;###autoload
(define-derived-mode jinja2-ts-mode prog-mode "Jinja2"
  "Major mode for Jinja templates, powered by tree-sitter."
  :group 'jinja2-ts
  :syntax-table jinja2-ts-mode--syntax-table

  (setq-local comment-start "{# ")
  (setq-local comment-end " #}")
  (setq-local comment-start-skip "{#[+-]?[[:space:]]*")
  (setq-local comment-end-skip "[[:space:]]*[+-]?#}")
  (setq-local indent-tabs-mode nil)

  (when (treesit-ready-p 'jinja)
    (treesit-parser-create 'jinja)

    (setq-local treesit-simple-indent-rules jinja2-ts-mode--indent-rules)
    (setq-local treesit-defun-type-regexp
                (regexp-opt '("macro_block" "block_block")))
    (setq-local treesit-defun-name-function #'jinja2-ts-mode--defun-name)
    (setq-local treesit-simple-imenu-settings
                '(("Macro" "\\`macro_block\\'" nil nil)
                  ("Block" "\\`block_block\\'" nil nil)))

    (setq-local treesit-font-lock-settings
                jinja2-ts-mode--font-lock-settings)
    (setq-local treesit-font-lock-feature-list
                '((comment definition)
                  (keyword string)
                  (constant number)
                  (bracket delimiter function operator variable)))

    (treesit-major-mode-setup)))

;;;###autoload
(add-to-list 'auto-mode-alist
             '("\\.\\(?:j2\\|jinja\\|jinja2\\)\\'" . jinja2-ts-mode))

(provide 'jinja2-ts-mode)

(with-eval-after-load 'treesit-fold
  (require 'jinja2-ts-mode-treesit-fold))

;;; jinja2-ts-mode.el ends here
