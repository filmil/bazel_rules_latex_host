#!/usr/bin/env bash
# System poppler `pdfunite` wrapper (non-hermetic).
export PATH="/usr/bin:/bin:/usr/local/bin:${PATH:-}"
exec pdfunite "$@"
