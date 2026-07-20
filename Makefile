EMACS ?= emacs
BATCH = $(EMACS) -Q --batch
LOAD_PATH = -L . -L test
GRAMMAR_DIR ?= $(CURDIR)/.tree-sitter
GRAMMAR_SETUP = --eval "(add-to-list 'treesit-extra-load-path \"$(GRAMMAR_DIR)\")"

.PHONY: all install-grammar compile test clean

all: compile test

install-grammar:
	mkdir -p $(GRAMMAR_DIR)
	$(BATCH) \
		--eval "(require 'treesit)" \
		$(GRAMMAR_SETUP) \
		--eval "(add-to-list 'treesit-language-source-alist '(jinja \"https://github.com/cathaysia/tree-sitter-jinja\" \"v0.13.0\" \"tree-sitter-jinja/src\"))" \
		--eval "(unless (treesit-language-available-p 'jinja) (treesit-install-language-grammar 'jinja \"$(GRAMMAR_DIR)\"))"

compile:
	$(BATCH) $(LOAD_PATH) \
		--eval "(setq byte-compile-error-on-warn t)" \
		-f batch-byte-compile jinja2-ts-mode.el

test: install-grammar
	$(BATCH) $(LOAD_PATH) $(GRAMMAR_SETUP) \
		-l jinja2-ts-mode-test \
		-f ert-run-tests-batch-and-exit

clean:
	find . -name '*.elc' -delete

