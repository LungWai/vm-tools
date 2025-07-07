#!/usr/bin/env bash
set -euo pipefail

echo "─── Cursor Extension Bulk-Installer ───"

### 1️⃣  Find a working 'code' CLI inside ~/.cursor-server
if command -v code >/dev/null 2>&1; then
  CODE_CLI=$(command -v code)
else
  CODE_CLI=$(find "$HOME/.cursor-server/bin" -type f -name code -perm /u+x | head -n1 || true)
fi

if [[ -z "${CODE_CLI:-}" ]]; then
  echo "❌ Could not locate a 'code' CLI. Make sure you've opened this VM once with Cursor Remote-SSH."
  exit 1
fi
echo "✅ Using CLI: $CODE_CLI"

### 2️⃣  Grab the extension list
EXT_URL="https://raw.githubusercontent.com/LungWai/vm-tools/main/extensions.txt"
EXT_FILE="$(mktemp)"
curl -fsSL "$EXT_URL" -o "$EXT_FILE"

### 3️⃣  Install extensions
while IFS= read -r ext || [[ -n $ext ]]; do
  [[ $ext =~ ^\s*# || -z $ext ]] && continue   # skip comments / blanks
  echo "📦  Installing $ext"
  "$CODE_CLI" --install-extension "$ext" --force
done < "$EXT_FILE"

echo "🎉  All extensions installed for this Cursor server."
