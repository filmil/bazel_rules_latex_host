#!/usr/bin/env bash
# Install the host tools the (non-hermetic) system LaTeX toolchain shells out
# to: a TeX engine (pdflatex) with common LaTeX packages (IEEEtran, tikz/pgf,
# listings, booktabs, enumitem, multirow, lmodern, microtype, hyperref,
# amsmath/amssymb, ...), plus poppler-utils (pdfinfo, pdfunite) and
# ghostscript (gs).
#
# Usage:  bazel run @rules_latex_host//latex:install_tools
#     or: bash latex/install-tools.sh
#
# Detects the platform package manager. Uses sudo when not run as root.
set -euo pipefail

have() { command -v "$1" >/dev/null 2>&1; }

SUDO=""
if [ "$(id -u)" -ne 0 ] && have sudo; then
  SUDO="sudo"
fi

echo ">> Installing TeX + poppler-utils + ghostscript ..."
if have apt-get; then
  echo ">> Debian/Ubuntu (apt-get)"
  $SUDO apt-get update
  $SUDO apt-get install -y --no-install-recommends \
    texlive-latex-base texlive-latex-recommended texlive-latex-extra \
    texlive-fonts-recommended texlive-pictures texlive-publishers \
    texlive-science lmodern \
    poppler-utils ghostscript
elif have dnf; then
  echo ">> Fedora (dnf)"
  $SUDO dnf install -y \
    texlive-scheme-medium texlive-ieeetran texlive-pgf texlive-listings \
    texlive-booktabs texlive-enumitem texlive-multirow texlive-lm \
    texlive-microtype texlive-hyperref \
    poppler-utils ghostscript
elif have yum; then
  echo ">> RHEL/CentOS (yum)"
  $SUDO yum install -y \
    texlive-latex texlive-ieeetran texlive-pgf texlive-listings \
    texlive-collection-latexrecommended \
    poppler-utils ghostscript
elif have pacman; then
  echo ">> Arch (pacman)"
  $SUDO pacman -Sy --noconfirm \
    texlive-latex texlive-latexextra texlive-fontsrecommended \
    texlive-pictures texlive-publishers \
    poppler ghostscript
elif have zypper; then
  echo ">> openSUSE (zypper)"
  $SUDO zypper install -y \
    texlive-latex texlive-ieeetran texlive-pgf texlive-listings \
    texlive-booktabs texlive-enumitem texlive-multirow texlive-lm \
    poppler-tools ghostscript
elif have brew; then
  echo ">> macOS (Homebrew)"
  brew install --cask mactex-no-gui || brew install texlive
  brew install poppler ghostscript
else
  cat >&2 <<'EOF'
!! No supported package manager found (apt-get/dnf/yum/pacman/zypper/brew).
   Install manually:
     - a TeX distribution providing pdflatex plus: IEEEtran, tikz/pgf,
       listings, booktabs, enumitem, multirow, lmodern, microtype, hyperref,
       amsmath, amssymb, array, longtable, caption, float
     - poppler-utils  (pdfinfo, pdfunite)
     - ghostscript    (gs)
EOF
  exit 1
fi

echo
echo ">> Verifying tools on PATH:"
ok=1
for t in pdflatex pdfinfo pdfunite gs; do
  if have "$t"; then
    printf "   %-9s %s\n" "$t" "$(command -v "$t")"
  else
    printf "   %-9s MISSING\n" "$t"
    ok=0
  fi
done

if [ "$ok" -eq 1 ]; then
  echo ">> All tools present."
else
  echo "!! Some tools are still missing; see messages above." >&2
  exit 1
fi
