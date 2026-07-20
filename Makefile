EMACS ?= emacs
BATCH = $(EMACS) -Q --batch
LOAD_PATH = -L . -L test
GRAMMAR_DIR ?= $(CURDIR)/.tree-sitter
GRAMMAR_SETUP = --eval "(add-to-list 'treesit-extra-load-path \"$(GRAMMAR_DIR)\")"
TREESIT_FOLD_URL = https://github.com/emacs-tree-sitter/treesit-fold
SOURCES = jinja2-ts-mode.el jinja2-ts-mode-treesit-fold.el

PACKAGE_SETUP = \
	--eval "(require 'package)" \
	--eval "(package-initialize)" \
	--eval "(setq load-prefer-newer t)"

.PHONY: all install-deps install-grammar compile test clean

all: install-deps compile test

install-deps:
	$(BATCH) $(PACKAGE_SETUP) \
		--eval "(unless (package-installed-p 'treesit-fold) (package-vc-install \"$(TREESIT_FOLD_URL)\"))"

install-grammar:
	mkdir -p $(GRAMMAR_DIR)
	$(BATCH) \
		--eval "(require 'treesit)" \
		$(GRAMMAR_SETUP) \
		--eval "(add-to-list 'treesit-language-source-alist '(jinja \"https://github.com/cathaysia/tree-sitter-jinja\" \"v0.13.0\" \"tree-sitter-jinja/src\"))" \
		--eval "(unless (treesit-language-available-p 'jinja) (treesit-install-language-grammar 'jinja \"$(GRAMMAR_DIR)\"))"

compile:
	$(BATCH) $(LOAD_PATH) $(PACKAGE_SETUP) \
		--eval "(setq byte-compile-error-on-warn t)" \
		-f batch-byte-compile $(SOURCES)

test: install-grammar
	$(BATCH) $(LOAD_PATH) $(PACKAGE_SETUP) $(GRAMMAR_SETUP) \
		-l jinja2-ts-mode-test \
		-f ert-run-tests-batch-and-exit

clean:
	find . -name '*.elc' -delete
