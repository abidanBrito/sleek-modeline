pkg := "sleek-modeline"

emacs := env_var_or_default("EMACS", "emacs")
elpa-dir  := justfile_directory() / ".local-elpa"

tools := "package-lint relint"
pkg-init := "(progn (setq package-user-dir \"" + elpa-dir + "\") (require (quote package)) (add-to-list (quote package-archives) (cons \"melpa\" \"https://melpa.org/packages/\") t) (package-initialize))"

batch  := emacs + " -Q --batch -L ."
ebatch := batch + " --eval '" + pkg-init + "'"

source-files := `find . -maxdepth 1 -name '*.el' ! -name '*-autoloads.el' ! -name '.dir-locals.el' | sort | tr '\n' ' '`

@_default:
    just --list

# Run every check, like CI does
all: build lint relint

# Build everything
build: compile autoloads

# Byte-compile all source files
compile:
    @{{batch}} --eval "(setq byte-compile-error-on-warn t)" \
    -f batch-byte-compile {{source-files}}

# Generate the autoloads file
autoloads:
    @{{batch}} --eval "(let ((out (expand-file-name \"{{pkg}}-autoloads.el\"))) \
    (cond ((require 'loaddefs-gen nil t) \
    (loaddefs-generate default-directory out)) \
    ((fboundp 'make-directory-autoloads) \
    (make-directory-autoloads default-directory out)) \
    (t (message \"Skipping autoloads: unsupported Emacs version\"))))"

# Lint against MELPA rules
lint: _tools
    @{{ebatch}} --eval "(setq package-lint-main-file \"{{pkg}}.el\")" \
    -f package-lint-batch-and-exit {{source-files}}

# Check regular expressions and docstring escapes
relint: _tools
    @{{ebatch}} -l relint -f relint-batch {{source-files}}

# Install lint tooling
_tools:
    #!/usr/bin/env bash
    set -euo pipefail
    stamp="{{elpa-dir}}/.tools-installed"
    if [ -f "$stamp" ]; then exit 0; fi
    {{ebatch}} --eval '(package-refresh-contents)' \
    --eval '(dolist (p (quote ({{tools}}))) (unless (package-installed-p p) (package-install p)))'
    touch "$stamp"

# Remove all build artifacts
clean:
    @rm -f ./*.elc {{pkg}}-autoloads.el
    @rm -rf {{elpa-dir}}
