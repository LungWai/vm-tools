#!/bin/bash

# Print usage instructions to the terminal
echo "##########################################################################"
echo "# 🛠 INSTRUCTIONS: How to generate your SSH key before using this script"
echo "#"
echo "# ▶️ RECOMMENDED: Generate a modern ed25519 SSH key:"
echo "#"
echo "#    ssh-keygen -t ed25519 -f ~/.ssh/my_devuser_key -C \"devuser key\""
echo "#"
echo "#    👉 On Windows (PowerShell):"
echo "#    ssh-keygen -t ed25519 -f C:\\Users\\YOURNAME\\keys\\my_devuser_key -C \"devuser key\""
echo "#"
echo "# ▶️ ALTERNATIVE: Generate an RSA key (for older compatibility):"
echo "#"
echo "#    ssh-keygen -t rsa -b 4096 -f ~/.ssh/my_devuser_key -C \"devuser key\""
echo "#"
echo "#    👉 On Windows (PowerShell):"
echo "#    ssh-keygen -t rsa -b 4096 -f C:\\Users\\YOURNAME\\keys\\my_devuser_key -C \"devuser key\""
echo "#"
echo "# 2. This generates:"
echo "#    - A private key:   my_devuser_key      ← DO NOT share this file"
echo "#    - A public key:    my_devuser_key.pub  ← You’ll copy/paste this into the script"
echo "#"
echo "# 3. Display the public key to copy:"
echo "#"
echo "#    cat ~/.ssh/my_devuser_key.pub          # (macOS/Linux)"
echo "#    type my_devuser_key.pub                # (Windows)"
echo "#"
echo "# 4. Run this script as root on your server:"
echo "#"
echo "#    sudo su"
echo "#    ./add_ssh_user.sh"
echo "#"
echo "# 5. Paste the public key when prompted and press:"
echo "#    - Enter"
echo "#    - Ctrl+D (to finish input)"
echo "#"
echo "# 6. The script will:"
echo "#    - Create a user"
echo "#    - Set up SSH access"
echo "#    - Optionally grant passwordless sudo"
echo "##########################################################################"
echo ""

# Must be run as root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run this script as root using 'sudo su' or 'sudo ./add_ssh_user.sh'"
  exit 1
fi

echo "👤 Enter the new username you want to create:"
read username

# Check if user already exists
if id "$username" &>/dev/null; then
    echo "⚠️ User '$username' already exists. Exiting."
    exit 1
fi

# Create the user without password
adduser --disabled-password --gecos "" "$username"
echo "✅ User '$username' created."

# Ask if the user should have sudo access
echo "🔐 Grant '$username' sudo privileges with NO password? (y/n)"
read give_sudo
if [[ "$give_sudo" =~ ^[Yy]$ ]]; then
    usermod -aG sudo "$username"
    echo "$username ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/"$username"
    chmod 440 /etc/sudoers.d/"$username"
    echo "✅ User '$username' granted passwordless sudo access."
fi

# Prompt for SSH public key
echo "📥 Paste the public SSH key for $username (then press Enter, Ctrl+D when done):"
pubkey=$(</dev/st
