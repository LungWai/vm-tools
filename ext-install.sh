#!/bin/bash

echo "--- Installing VSCode / Cursor Extensions from extensions.txt ---"

# Ensure `code` CLI is available
if ! command -v code &> /dev/null; then
  echo "Error: 'code' CLI not found. Please install VSCode or Cursor and ensure the CLI is available in PATH."
  exit 1
fi

# Fetch extensions.txt from GitHub
EXT_LIST_URL="https://raw.githubusercontent.com/LungWai/vm-tools/main/extensions.txt"
EXT_TEMP_FILE="/tmp/extensions.txt"

curl -fsSL "$EXT_LIST_URL" -o "$EXT_TEMP_FILE" || {
  echo "Failed to download extensions.txt"
  exit 1
}

# Install extensions line-by-line
while IFS= read -r ext || [[ -n "$ext" ]]; do
  [[ "$ext" =~ ^#.*$ || -z "$ext" ]] && continue  # skip comments and empty lines
  echo "Installing: $ext"
  code --install-extension "$ext" --force
done < "$EXT_TEMP_FILE"

echo "--- All extensions installed successfully ---"
