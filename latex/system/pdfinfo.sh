#!/usr/bin/env bash
# System poppler `pdfinfo` wrapper (non-hermetic).
export PATH="/usr/bin:/bin:/usr/local/bin:${PATH:-}"
exec pdfinfo "$@"
