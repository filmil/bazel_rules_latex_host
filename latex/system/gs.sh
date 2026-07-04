#!/usr/bin/env bash
# System ghostscript wrapper (non-hermetic).
export PATH="/usr/bin:/bin:/usr/local/bin:${PATH:-}"
exec gs "$@"
