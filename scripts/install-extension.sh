#!/bin/bash
# Installs the LockedIn sensor extension into every VS Code-based editor found
# (Cursor, Antigravity, VS Code, Windsurf, VSCodium). The extension uses only the
# standard VS Code API, so one copy works in all of them.
set -euo pipefail
cd "$(dirname "$0")/.."

SRC="cursor-extension"
NAME="lockedin.lockedin-sensor-0.1.0"
installed=0

for base in ~/.cursor ~/.antigravity ~/.vscode ~/.windsurf ~/.vscode-oss; do
  dir="$base/extensions"
  [ -d "$dir" ] || continue
  dest="$dir/$NAME"
  rm -rf "$dest"
  mkdir -p "$dest"
  cp "$SRC/package.json" "$SRC/extension.js" "$dest/"
  echo "installed → $dest"
  installed=$((installed + 1))
done

if [ "$installed" -eq 0 ]; then
  echo "No VS Code-based editors found."
else
  echo "Done ($installed editor(s)). Restart the editor (or Reload Window) to activate."
fi
