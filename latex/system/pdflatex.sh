#!/usr/bin/env bash
# System TeX engine wrapper (non-hermetic). Replace the registered toolchain to
# vendor a hermetic pdflatex.
export PATH="/usr/bin:/bin:/usr/local/bin:${PATH:-}"
exec pdflatex "$@"
