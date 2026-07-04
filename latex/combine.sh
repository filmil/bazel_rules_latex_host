#!/usr/bin/env bash
# Concatenate several PDFs into one, with a top-level per-part outline.
#
#   combine.sh <out.pdf> <titles-file> <part1.pdf> <part2.pdf> ...
#
# <titles-file> holds one bookmark title per line: line i names part i. Missing
# lines (fewer titles than parts) fall back to "Part <n>". The TeX/PDF tools are
# taken from $PDFINFO / $PDFUNITE / $GS when set (so the LaTeX toolchain can
# inject hermetic binaries), otherwise from PATH. Bookmark page-offsets are
# computed from actual page counts, so the outline stays correct as any part's
# length changes.
set -euo pipefail
PDFINFO="${PDFINFO:-pdfinfo}"
PDFUNITE="${PDFUNITE:-pdfunite}"
GS="${GS:-gs}"

out="$1"; shift
titles_file="$1"; shift
titles=()
if [[ -f "$titles_file" ]]; then
  mapfile -t titles < "$titles_file"
fi
files=("$@")

d="$(mktemp -d)"
trap 'rm -rf "$d"' EXIT

offset=1
: > "$d/marks.ps"
for i in "${!files[@]}"; do
  title="${titles[$i]:-Part $((i + 1))}"
  echo "[/Title ($title) /Page $offset /OUT pdfmark" >> "$d/marks.ps"
  pages="$("$PDFINFO" "${files[$i]}" | awk '/Pages/{print $2}')"
  offset=$((offset + pages))
done

"$PDFUNITE" "${files[@]}" "$d/merged.pdf"
"$GS" -dBATCH -dNOPAUSE -q -sDEVICE=pdfwrite -sOutputFile="$out" \
   "$d/merged.pdf" "$d/marks.ps"
