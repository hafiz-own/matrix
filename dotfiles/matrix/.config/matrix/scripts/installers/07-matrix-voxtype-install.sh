#!/bin/bash
# DESC: Voxtype audio transcriber installation
# matrix-voxtype-install.sh
# Installation script for Voxtype inside the Matrix ecosystem

# DESC: Installs Voxtype audio transcription and hardware acceleration dependencies.

# Fail fast, fail loud
set -Eeuo pipefail
trap 'echo -e "\e[31m[!] Error: Script failed on line \$LINENO\e[0m" >&2' ERR

# Standard logging functions
info()    { echo -e "\e[34m[*]\e[0m \$1"; }
warn()    { echo -e "\e[33m[!]\e[0m \$1"; }
die()     { echo -e "\e[31m[✘]\e[0m \$1" >&2; exit 1; }
success() { echo -e "\e[32m[✔]\e[0m \$1"; }

# Help Menu
show_help() {
    cat << EOF
Usage: \$(basename "\$0") [OPTIONS]

Installs Voxtype audio transcription and hardware acceleration dependencies.

Options:
  -h, --help    Show this help message and exit
EOF
}

if [[ "\${1:-}" == "-h" || "\${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi


set -e

if gum confirm "Install Voxtype + AI model (~150MB) to enable dictation?"; then
  # Install necessary packages natively via Paru
  paru -S --needed wtype voxtype-bin

  # Setup voxtype configuration directory
  mkdir -p ~/.config/voxtype
  
  # Copy Matrix-specific Voxtype config
  cp "$HOME/.config/matrix/scripts/system-configs/voxtype_config.toml" ~/.config/voxtype/config.toml

  # Download the model and run setup silently
  voxtype setup --download --no-post-install
  
  # Enable hardware acceleration (Nvidia CUDA)
  if command -v nvidia-smi &> /dev/null; then
    sudo voxtype setup gpu --enable || true
  fi
  
  # Enable the Voxtype daemon in systemd
  voxtype setup systemd

  # Reload Waybar to pick up the new module
  if command -v waybar &> /dev/null; then
    pkill -SIGUSR2 waybar || true
  fi

  notify-send -u normal -a "Matrix Dictation" "Voxtype Dictation Ready" "Hold F9 to dictate (or toggle with Super + Ctrl + X)."
fi
