#!/usr/bin/env bash
# Regenerate the guide diagrams from their Mermaid sources.
#
# The .mmd files in this folder are the editable source of truth. The .svg files
# beside them are what the Markdown, HTML and PDF actually reference — Markdown
# renderers other than GitHub do not render Mermaid, so the guide links images.
#
# Edit a .mmd, run this, commit both files.
#
# Requires: Node (for npx) and Google Chrome. Both are already needed by build.sh.
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ -f "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]]; then
  export PUPPETEER_EXECUTABLE_PATH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
elif command -v google-chrome &>/dev/null; then
  export PUPPETEER_EXECUTABLE_PATH="$(command -v google-chrome)"
fi

shopt -s nullglob
for src in "$DIR"/*.mmd; do
  out="${src%.mmd}.svg"
  echo "Rendering $(basename "$src") -> $(basename "$out")"
  npx -y @mermaid-js/mermaid-cli@11 \
    -i "$src" -o "$out" \
    -c "$DIR/theme.json" \
    -b white --quiet
done

echo "Done. Re-run ../build.sh to refresh the HTML and PDF."
