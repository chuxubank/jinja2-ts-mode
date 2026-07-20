EMACS ?= emacs
BATCH = $(EMACS) -Q --batch
LOAD_PATH = -L . -L test
LOAD_SETUP = --eval "(setq load-prefer-newer t)"
GRAMMAR_DIR ?= $(CURDIR)/.tree-sitter
GRAMMAR_SETUP = --eval "(add-to-list 'treesit-extra-load-path \"$(GRAMMAR_DIR)\")"
SOURCES = jinja2-ts-mode.el jinja2-ts-mode-treesit-fold.el
TEST_SOURCES = test/jinja2-ts-mode-test.el

.PHONY: all install-grammar compile test test-optional-fold clean

all: compile test

install-grammar:
	mkdir -p $(GRAMMAR_DIR)
	$(BATCH) \
		--eval "(require 'treesit)" \
		$(GRAMMAR_SETUP) \
		--eval "(add-to-list 'treesit-language-source-alist '(jinja \"https://github.com/cathaysia/tree-sitter-jinja\" \"v0.13.0\" \"tree-sitter-jinja/src\"))" \
		--eval "(unless (treesit-language-available-p 'jinja) (condition-case nil (treesit-install-language-grammar 'jinja \"$(GRAMMAR_DIR)\") (wrong-number-of-arguments (treesit-install-language-grammar 'jinja))))"

compile:
	$(BATCH) $(LOAD_PATH) $(LOAD_SETUP) \
		--eval "(setq byte-compile-error-on-warn t)" \
		-f batch-byte-compile $(SOURCES)

test: install-grammar test-optional-fold
	$(BATCH) $(LOAD_PATH) $(LOAD_SETUP) $(GRAMMAR_SETUP) \
		-l jinja2-ts-mode-test \
		-f ert-run-tests-batch-and-exit

test-optional-fold:
	@set -e; tmp=$$(mktemp -d); trap 'rm -rf "$$tmp"' 0; \
		mkdir "$$tmp/test"; \
		cp $(SOURCES) "$$tmp"; \
		cp $(TEST_SOURCES) "$$tmp/test"; \
		$(BATCH) -L "$$tmp" -L "$$tmp/test" \
			--eval "(setq byte-compile-error-on-warn t)" \
			-f batch-byte-compile "$$tmp"/*.el "$$tmp"/test/*.el; \
		$(BATCH) -L "$$tmp" \
			--eval "(defvar treesit-fold-range-alist nil)" \
			--eval "(provide 'treesit-fold)" \
			-l jinja2-ts-mode \
			--eval "(unless (alist-get 'jinja2-ts-mode treesit-fold-range-alist) (error \"Jinja2 fold ranges were not registered\"))"

clean:
	find . -name '*.elc' -delete
