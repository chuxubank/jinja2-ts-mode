# jinja2-ts-mode

`jinja2-ts-mode` is an Emacs 29+ tree-sitter major mode for Jinja and
Jinja2 templates. It provides semantic font locking, block indentation,
comments, defun navigation, and Imenu entries for macros and blocks.

The mode uses the [`jinja`](https://github.com/cathaysia/tree-sitter-jinja)
grammar. That grammar exposes structured expressions, function calls,
operators, literals, filters, tests, and nested template blocks rather than
treating expression bodies as opaque text.

## Installation

Install directly from GitHub with `package-vc`:

```elisp
(use-package jinja2-ts-mode
  :vc (:url "https://github.com/chuxubank/jinja2-ts-mode"))
```

Then install the grammar once:

```text
M-x jinja2-ts-mode-install-grammar
```

Files ending in `.j2`, `.jinja`, or `.jinja2` automatically use
`jinja2-ts-mode`. To retain a host language such as JSON, YAML, or HTML,
use `poly-any-jinja2` from
[`poly-any-template`](https://github.com/chuxubank/poly-any-template).

## Development

```sh
make
```

The Makefile builds the pinned grammar locally, byte-compiles the package,
and runs the ERT test suite.

## License

GPL-3.0-or-later. The tree-sitter grammar is a separate project and is not
bundled with this package.

