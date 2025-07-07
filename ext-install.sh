#!/bin/bash

set -e
echo "--- Installing Cursor Server Extensions (Hardcoded Version) ---"

# Hardcoded Cursor server version
CURSOR_COMMIT_HASH="96e5b01ca25f8fbd4c4c10bc69b15f6228c80770"
CURSOR_SERVER_BIN="$HOME/.cursor-server/bin/$CURSOR_COMMIT_HASH/cursor-server"
EXT_DIR="$HOME/.cursor-server/extensions"

# Check for the cursor-server binary
if [ ! -f "$CURSOR_SERVER_BIN" ]; then
  echo "❌ Cursor server binary not found at $CURSOR_SERVER_BIN"
  echo "➡️  Please connect once using Cursor Remote SSH to let it install the server."
  exit 1
fi

echo "✅ Using cursor-server at: $CURSOR_SERVER_BIN"

# Download extensions list
EXT_LIST_URL="https://raw.githubusercontent.com/LungWai/vm-tools/main/extensions.txt"
EXT_TEMP_FILE="/tmp/extensions.txt"

curl -fsSL "$EXT_LIST_URL" -o "$EXT_TEMP_FILE" || {
  echo "Failed to download extensions.txt"
  exit 1
}

# Install extensions
mkdir -p "$EXT_DIR"

while IFS= read -r ext || [[ -n "$ext" ]]; do
  [[ "$ext" =~ ^#.*$ || -z "$ext" ]] && continue
  echo "📦 Installing: $ext"
  "$CURSOR_SERVER_BIN" \
    --install-extension "$ext" \
    --extensions-dir "$EXT_DIR" \
    --force
done < "$EXT_TEMP_FILE"

echo "--- ✅ All extensions installed into Cursor Server ---"
