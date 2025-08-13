#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Dual-mode setup script
# - Non-root: user-space only (no apt, no sudo, no system writes)
# - Root (e.g., sudo bash): full system install (apt + Docker)
#
# Tools:
# 1) NVM + Node LTS + npm (user-space in both modes)
# 2) Python/pip (system via apt in root mode; otherwise use existing python3 if present)
# 3) Anthropic Claude Code CLI (npm global in user-space)
# 4) Git (system via apt in root mode; otherwise use existing git if present)
# 5) uv installer (user-space)
# 6) Docker (root mode: system Docker; non-root: prints next steps for rootless or later sudo)
# ============================================================

log()  { printf "\033[1;32m[+] %s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m[!] %s\033[0m\n" "$*"; }
err()  { printf "\033[1;31m[✗] %s\033[0m\n" "$*" 1>&2; }
have() { command -v "$1" >/dev/null 2>&1; }

IS_ROOT="false"
if [ "${EUID:-$(id -u)}" -eq 0 ]; then
  IS_ROOT="true"
fi

# Detect the "real" user when run via sudo, for adding to docker group, etc.
REAL_USER="${SUDO_USER:-${USER:-$(id -un)}}"
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6 2>/dev/null || echo "$HOME")"

log "--- Starting Environment Setup (root: ${IS_ROOT}) ---"

# ------------------------------------------------------------
# 1) NVM + Node LTS (always user-space)
# ------------------------------------------------------------
log "Installing NVM and Node.js (user-space)..."
# Install NVM into the invoking user's home (even when root, we still install for REAL_USER)
# If running as root for a different REAL_USER, we need to run the NVM installer as that user.
install_nvm_for_user() {
  local usr="$1" home_dir="$2"
  local nvm_dir="$home_dir/.nvm"

  # Fetch installer as the target user
  if [ "$IS_ROOT" = "true" ] && [ "$usr" != "root" ]; then
    sudo -H -u "$usr" bash -c "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash"
  else
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
  fi

  # Source NVM for this shell if we're configuring our own account
  if [ "$home_dir" = "$HOME" ]; then
    export NVM_DIR="$nvm_dir"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
    nvm install --lts
    nvm alias default 'lts/*'
  else
    # Configure Node LTS for the REAL_USER
    if [ "$IS_ROOT" = "true" ]; then
      sudo -H -u "$usr" bash -lc '
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
        nvm install --lts
        nvm alias default "lts/*"
      '
    fi
  fi

  # Ensure PATH updates persist for interactive shells of REAL_USER
  local shell_rc="$home_dir/.bashrc"
  if ! grep -q 'NVM_DIR=.*\.nvm' "$shell_rc" 2>/dev/null; then
    cat >> "$shell_rc" <<'EOF'
# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
EOF
  fi
}

# Need curl for NVM bootstrap
if ! have curl; then
  if [ "$IS_ROOT" = "true" ]; then
    log "Installing curl (root mode)..."
    apt-get update -y
    apt-get install -y curl
  else
    err "curl is required for user-space install but not found. Please install curl or rerun with sudo."
    exit 1
  fi
fi

install_nvm_for_user "$REAL_USER" "$REAL_HOME"

# Load NVM in *this* shell if possible
if [ -d "$REAL_HOME/.nvm" ]; then
  export NVM_DIR="$REAL_HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
fi

# Use LTS in this shell if available
if have nvm; then
  nvm use --lts >/dev/null 2>&1 || true
fi

# ------------------------------------------------------------
# 2) Python & Pip
# ------------------------------------------------------------
if [ "$IS_ROOT" = "true" ]; then
  log "Installing Python and Pip (system, root mode)..."
  apt-get update -y
  apt-get install -y python3 python3-pip python3-venv
else
  if have python3 && have pip3; then
    log "Using existing Python: $(python3 --version 2>/dev/null || true)"
  else
    warn "Python3/pip3 not found and we are non-root. Skipping system install. (You can rerun with sudo to install system Python.)"
  fi
fi

# ------------------------------------------------------------
# 3) Anthropic Claude Code CLI (user-space npm global)
# ------------------------------------------------------------
log "Installing Anthropic Claude Code CLI (user-space)..."
# Ensure npm global installs go to user directory to avoid EACCES
if have npm; then
  # Prefer nvm-managed prefix; fall back to ~/.npm-global
  NPM_PREFIX="$(npm config get prefix 2>/dev/null || true)"
  if [ "$IS_ROOT" = "false" ]; then
    if [ -z "$NPM_PREFIX" ] || [[ "$NPM_PREFIX" == /usr/* || "$NPM_PREFIX" == /usr/local* ]]; then
      npm config set prefix "$REAL_HOME/.npm-global"
      mkdir -p "$REAL_HOME/.npm-global"
      # Add to PATH for future shells
      if ! grep -q 'npm-global' "$REAL_HOME/.bashrc" 2>/dev/null; then
        echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$REAL_HOME/.bashrc"
      fi
      export PATH="$REAL_HOME/.npm-global/bin:$PATH"
    fi
  fi

  # Install as the REAL_USER to ensure proper ownership
  if [ "$IS_ROOT" = "true" ] && [ "$REAL_USER" != "root" ]; then
    sudo -H -u "$REAL_USER" bash -lc 'npm i -g @anthropic-ai/claude-code'
  else
    npm i -g @anthropic-ai/claude-code
  fi

  # Make sure current shell can see it
  export PATH="$(npm config get prefix)/bin:$PATH" || true
else
  warn "npm not found. Node may not have installed correctly; check NVM setup."
fi

# ------------------------------------------------------------
# 4) Git + credential cache
# ------------------------------------------------------------
if [ "$IS_ROOT" = "true" ]; then
  log "Installing Git (system, root mode)..."
  apt-get install -y git
else
  if ! have git; then
    warn "git not found and we are non-root. Skipping git install. (Rerun with sudo to install system git.)"
  fi
fi

# Configure git cache for the REAL_USER (if git exists)
if have git; then
  if [ "$IS_ROOT" = "true" ] && [ "$REAL_USER" != "root" ]; then
    sudo -H -u "$REAL_USER" git config --global credential.helper 'cache --timeout=604800'
  else
    git config --global credential.helper 'cache --timeout=604800' || true
  fi
fi

# ------------------------------------------------------------
# 5) Clone & set up Claude Code Usage Monitor (user-space)
# ------------------------------------------------------------
REPO_URL="https://github.com/Maciek-roboblog/Claude-Code-Usage-Monitor.git"
TARGET_DIR="$REAL_HOME/Claude-Code-Usage-Monitor"
if have git; then
  log "Cloning/updating Claude Code Usage Monitor (user-space)..."
  if [ -d "$TARGET_DIR/.git" ]; then
    if [ "$IS_ROOT" = "true" ] && [ "$REAL_USER" != "root" ]; then
      sudo -H -u "$REAL_USER" git -C "$TARGET_DIR" pull --ff-only
    else
      git -C "$TARGET_DIR" pull --ff-only || true
    fi
  else
    if [ "$IS_ROOT" = "true" ] && [ "$REAL_USER" != "root" ]; then
      sudo -H -u "$REAL_USER" git clone "$REPO_URL" "$TARGET_DIR"
    else
      git clone "$REPO_URL" "$TARGET_DIR"
    fi
  fi
else
  warn "Skipping repository clone (git not available in non-root mode)."
fi

# Install uv (user-space)
log "Installing uv (user-space)..."
if [ "$IS_ROOT" = "true" ] && [ "$REAL_USER" != "root" ]; then
  sudo -H -u "$REAL_USER" bash -lc 'curl -LsSf https://astral.sh/uv/install.sh | sh'
  sudo -H -u "$REAL_USER" bash -lc 'mkdir -p "$HOME/.local/bin" && echo "export PATH=\$HOME/.local/bin:\$PATH" >> "$HOME/.bashrc"'
else
  curl -LsSf https://astral.sh/uv/install.sh | sh
  mkdir -p "$REAL_HOME/.local/bin"
  if ! grep -q '\.local/bin' "$REAL_HOME/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$REAL_HOME/.bashrc"
  fi
  export PATH="$REAL_HOME/.local/bin:$PATH"
fi

# ------------------------------------------------------------
# 6) Docker
# ------------------------------------------------------------
if [ "$IS_ROOT" = "true" ]; then
  log "Setting up Docker repository (OS-aware) and installing Docker Engine (root mode)..."
  apt-get update -y
  apt-get install -y ca-certificates curl gnupg

  . /etc/os-release
  if [[ "${ID:-}" = "ubuntu" || "${ID_LIKE:-}" == *ubuntu* ]]; then
    DOCKER_DISTRO="ubuntu"
    DOCKER_CODENAME="${VERSION_CODENAME:-noble}"
  elif [[ "${ID:-}" = "debian" || "${ID_LIKE:-}" == *debian* ]]; then
    DOCKER_DISTRO="debian"
    DOCKER_CODENAME="${VERSION_CODENAME:-bookworm}"
  else
    err "Unsupported distro for Docker: ID=${ID:-?} ID_LIKE=${ID_LIKE:-?}"
    exit 1
  fi

  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/${DOCKER_DISTRO}/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${DOCKER_DISTRO} ${DOCKER_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list

  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  # Add REAL_USER to docker group (if not root)
  if id -nG "$REAL_USER" 2>/dev/null | grep -qw docker; then
    log "User '$REAL_USER' already in docker group."
  else
    usermod -aG docker "$REAL_USER" || true
    warn "Added '$REAL_USER' to 'docker' group. Log out and log back in (or reboot) for it to take effect."
  fi
else
  warn "Non-root mode: skipping Docker system install."
  warn "If you need Docker now, either rerun this script with sudo OR set up Docker Rootless separately."
  echo "Docs: https://docs.docker.com/engine/security/rootless/"
fi

# ------------------------------------------------------------
# Verification (best effort)
# ------------------------------------------------------------
log "--- Versions (best effort) ---"
if have node;   then echo "Node: $(node -v)"; fi
if have npm;    then echo "npm:  $(npm -v)"; fi
if have python3; then echo "Python: $(python3 --version 2>/dev/null)"; fi
if have pip3;    then echo "Pip:    $(pip3 --version 2>/dev/null)"; fi
if have claude;  then echo "Claude: $(claude --version 2>/dev/null || echo 'installed')" ; else warn "claude not on PATH in this shell; open a new terminal or 'source ~/.bashrc'." ; fi
if have git;     then echo "Git:    $(git --version)"; fi
if have uv;      then echo "uv:     $(uv --version 2>/dev/null || true)"; fi
if have docker;  then echo "Docker: $(docker --version 2>/dev/null || true)"; fi

log "--- Installation Complete ---"
if [ "$IS_ROOT" = "true" ]; then
  echo "NOTE: If you were added to the 'docker' group, log out and back in (or reboot) to use 'docker' without sudo."
else
  echo "NOTE: Open a new shell or 'source ~/.bashrc' so PATH updates (nvm, npm-global, uv) take effect."
fi
