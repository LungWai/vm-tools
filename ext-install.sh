#!/bin/bash

set -e
echo "--- Installing Cursor Server Extensions ---"

# Auto-detect cursor commit hash
CURSOR_BIN_ROOT="$HOME/.cursor-server/bin"
CURSOR_COMMIT_HASH=$(basename "$(find "$CURSOR_BIN_ROOT" -maxdepth 1 -type d ! -name 'multiplex-server' | tail -n 1)")
CURSOR_SERVER_BIN="$CURSOR_BIN_ROOT/$CURSOR_COMMIT_HASH/cursor-server"
EXT_DIR="$HOME/.cursor-server/extensions"

if [ ! -f "$CURSOR_SERVER_BIN" ]; then
  echo "❌ Cursor server binary not found at $CURSOR_SERVER_BIN"
  exit 1
fi

echo "✅ Detected Cursor server: $CURSOR_COMMIT_HASH"
echo "Installing extensions using: $CURSOR_SERVER_BIN"

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
  echo "Installing: $ext"
  "$CURSOR_SERVER_BIN" \
    --install-extension "$ext" \
    --extensions-dir "$EXT_DIR" \
    --force
done < "$EXT_TEMP_FILE"

echo "--- All extensions installed into Cursor Remote Server ---"
