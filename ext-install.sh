#!/bin/bash

set -e
echo "--- Installing VSCode Server and Extensions for Cursor Remote SSH ---"

# Set this to your local Cursor/VSCode commit hash
VSCODE_COMMIT_HASH="96e5b01ca25f8fbd4c4c10bc69b15f6228c80770"
VSCODE_SERVER_DIR="$HOME/.vscode-server/bin/$VSCODE_COMMIT_HASH"
VSCODE_EXT_DIR="$HOME/.vscode-server/extensions"
VSCODE_SERVER_BIN="$VSCODE_SERVER_DIR/bin/code"

# 1. Download and extract VSCode server
if [ ! -d "$VSCODE_SERVER_DIR" ]; then
  echo "Downloading VSCode Server..."
  mkdir -p "$VSCODE_SERVER_DIR"
  cd "$VSCODE_SERVER_DIR"
  wget -q https://update.code.visualstudio.com/commit:$VSCODE_COMMIT_HASH/server-linux-x64/stable -O vscode-server.tar.gz
  tar -xzf vscode-server.tar.gz --strip-components=1
  rm vscode-server.tar.gz
else
  echo "VSCode Server already present at $VSCODE_SERVER_DIR"
fi

# 2. Download extension list
EXT_LIST_URL="https://raw.githubusercontent.com/LungWai/vm-tools/main/extensions.txt"
EXT_TEMP_FILE="/tmp/extensions.txt"

curl -fsSL "$EXT_LIST_URL" -o "$EXT_TEMP_FILE" || {
  echo "Failed to download extensions.txt"
  exit 1
}

# 3. Pre-install extensions using the VSCode server binary
mkdir -p "$VSCODE_EXT_DIR"

while IFS= read -r ext || [[ -n "$ext" ]]; do
  [[ "$ext" =~ ^#.*$ || -z "$ext" ]] && continue
  echo "Installing extension: $ext"
  "$VSCODE_SERVER_BIN" \
    --install-extension "$ext" \
    --extensions-dir "$VSCODE_EXT_DIR" \
    --force
done < "$EXT_TEMP_FILE"

echo "--- All extensions and VSCode Server installed successfully ---"
