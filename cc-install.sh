#!/bin/bash

# ---
# Installation & Setup Script
#
# This script installs and configures the following tools:
# 1. NVM (Node Version Manager) with Node.js and npm
# 2. Python and Pip
# 3. Anthropic Claude Code CLI
# 4. Git with credential caching
# 5. Claude Code Usage Monitor
# 6. Docker Engine
# ---

set -e # Exit immediately if a command exits with a non-zero status.

echo "--- Starting Environment Setup ---"

# 1. Install Node.js and NVM
# ---------------------------
echo "Installing NVM and Node.js..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

# Source nvm to make it available in the current shell session
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Install the latest LTS version of Node.js and set it as the default
nvm install --lts
nvm alias default 'lts/*'

# Verify installations
echo "Node.js version:"
node -v
echo "npm version:"
npm -v

# 2. Install Python and Pip
# -------------------------
echo "Installing Python and Pip..."
sudo apt-get update
sudo apt-get install -y python3 python3-pip python3-venv

# Verify Python installation
echo "Python version:"
python3 --version
echo "Pip version:"
pip3 --version

# 3. Install Anthropic Claude Code CLI
# ------------------------------------
echo "Installing Anthropic Claude Code CLI..."
npm install -g @anthropic-ai/claude-code

# 4. Install and Configure Git
# ------------------------------
echo "Installing and configuring Git..."
sudo apt-get install -y git
# Configure Git to cache credentials for 1 week (604800 seconds)
git config --global credential.helper 'cache --timeout=604800'

# 5. Set up Claude Code Usage Monitor
# ------------------------------------
echo "Cloning and setting up Claude Code Usage Monitor..."
git clone https://github.com/Maciek-roboblog/Claude-Code-Usage-Monitor.git
cd Claude-Code-Usage-Monitor

# Install 'uv', a fast Python package installer
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"

# Verify uv installation
echo "uv version:"
uv --version

# 6. Install Docker Engine
# -------------------------
echo "Setting up Docker repository and installing Docker Engine..."
# Add Docker's official GPG key
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repository to Apt sources
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

# Install Docker packages
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add the current user to the 'docker' group to run Docker without sudo
sudo usermod -aG docker $USER
newgrp docker

echo "---"
echo "--- Installation Complete! ---"
echo "---"
echo "IMPORTANT: For Docker permissions to apply, you must log out and log back in, or run 'newgrp docker'."
echo "---"