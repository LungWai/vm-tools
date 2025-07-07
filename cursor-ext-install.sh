#!/usr/bin/env bash
set -euo pipefail
echo "─── Cursor Extension Self-Healing Installer ───"

# ────────────────────────────────────────────────────────────────
# 1.  Cursor commit hash (hard-coded to your VM’s value)
# ────────────────────────────────────────────────────────────────
HASH="96e5b01ca25f8fbd4c4c10bc69b15f6228c80770"
SRV_ROOT="$HOME/.cursor-server/bin/$HASH"
CODE_CLI="$SRV_ROOT/bin/code"          # what we ultimately need

# ────────────────────────────────────────────────────────────────
# 2.  Ensure the server folder exists
# ────────────────────────────────────────────────────────────────
if [[ ! -d "$SRV_ROOT" ]]; then
  echo "Creating server folder $SRV_ROOT"
  mkdir -p "$SRV_ROOT"
fi

# ────────────────────────────────────────────────────────────────
# 3.  If the CLI is missing, fetch & unpack the server tarball
# ────────────────────────────────────────────────────────────────
if [[ ! -x "$CODE_CLI" ]]; then
  echo "⚠️  'code' CLI not found. Downloading server package…"
  TMP=$(mktemp -d)
  URL="https://update.code.visualstudio.com/commit:${HASH}/server-linux-x64/stable"
  echo "→ $URL"
  curl -#SL "$URL" -o "$TMP/server.tar.gz"
  tar -xzf "$TMP/server.tar.gz" -C "$SRV_ROOT" --strip-components=1
  rm -rf "$TMP"
fi

if [[ ! -x "$CODE_CLI" ]]; then
  echo "❌ Still no CLI at $CODE_CLI – aborting."
  exit 1
fi
echo "✅ Using CLI: $CODE_CLI"

# ────────────────────────────────────────────────────────────────
# 4.  Fetch the extension list
# ────────────────────────────────────────────────────────────────
EXT_URL="https://raw.githubusercontent.com/LungWai/vm-tools/main/extensions.txt"
EXT_FILE="$(mktemp)"
curl -fsSL "$EXT_URL" -o "$EXT_FILE"

# ────────────────────────────────────────────────────────────────
# 5.  Install extensions
# ────────────────────────────────────────────────────────────────
while IFS= read -r ext || [[ -n $ext ]]; do
  [[ $ext =~ ^\s*# || -z $ext ]] && continue
  echo "📦  Installing $ext"
  "$CODE_CLI" --install-extension "$ext" --force
done < "$EXT_FILE"

echo "🎉  All extensions installed for Cursor server $HASH"
