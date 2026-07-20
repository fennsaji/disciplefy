#!/bin/bash
# Regenerate a Content Playbook PDF (light + dark) from its Markdown source.
#
# Pipeline: pandoc -> styled HTML -> headless Chrome print-to-PDF. Chrome is what
# produced the original PDFs (Skia/PDF), so page breaks and table handling behave
# the same way.
#
# Requires: pandoc (brew install pandoc), Google Chrome.
#
# Usage:
#   ./playbook-pdf.sh <input.md> [outdir]
#
# Examples:
#   ./playbook-pdf.sh ../Content_Playbook_Season1/Content_Playbook_Season1_Week3.md
#   ./playbook-pdf.sh ../Content_Playbook_Season1/Content_Playbook_Season1_Week1.md /tmp/preview
#
# Output basename and PDF title are derived from the input filename:
#   Content_Playbook_Season1_Week3.md
#     -> Disciplefy_Season1_Week3.pdf  +  Disciplefy_Season1_Week3_Dark.pdf
#     -> title "Disciplefy Season 1 - Week 3"
#
# Note: the PDF/ output directory is gitignored — regenerated PDFs are not
# recoverable from git, so preview to a temp outdir first if unsure.

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

IN="${1:-}"
if [[ -z "$IN" || ! -f "$IN" ]]; then
  echo "usage: $(basename "$0") <input.md> [outdir]" >&2
  exit 1
fi
IN="$(cd "$(dirname "$IN")" && pwd)/$(basename "$IN")"

OUTDIR="${2:-$DIR/../Content_Playbook_Season1/PDF}"
mkdir -p "$OUTDIR"
OUTDIR="$(cd "$OUTDIR" && pwd)"

command -v pandoc >/dev/null || { echo "pandoc not found — brew install pandoc" >&2; exit 1; }
[[ -x "$CHROME" ]] || { echo "Chrome not found at $CHROME" >&2; exit 1; }

# Content_Playbook_Season1_Week3.md -> Disciplefy_Season1_Week3 / "Disciplefy Season 1 - Week 3"
STEM="$(basename "$IN" .md)"
BASE="Disciplefy_${STEM#Content_Playbook_}"
TITLE="$(echo "$BASE" | sed -e 's/_/ /g' -e 's/Season1/Season 1 -/' -e 's/Week\([0-9]\)/Week \1/')"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

render() {
  local theme="$1" suffix="$2"
  local html="$TMP/$BASE$suffix.html"

  pandoc "$IN" \
    --standalone \
    --from=gfm \
    --to=html5 \
    --metadata title="$TITLE" \
    --css="file://$DIR/theme-$theme.css" \
    --output="$html"

  "$CHROME" \
    --headless \
    --disable-gpu \
    --no-pdf-header-footer \
    --print-to-pdf="$OUTDIR/$BASE$suffix.pdf" \
    "file://$html" 2>/dev/null

  echo "  $OUTDIR/$BASE$suffix.pdf"
}

echo "$TITLE"
render light ""
render dark "_Dark"
