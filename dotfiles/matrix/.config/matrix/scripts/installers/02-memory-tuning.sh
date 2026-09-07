#!/usr/bin/env bash

# DESC: Configures ZRAM and memory management settings.

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

Configures ZRAM and memory management settings.

Options:
  -h, --help    Show this help message and exit
EOF
}

if [[ "\${1:-}" == "-h" || "\${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi


set -euo pipefail

# DESC: Memory and Swap Tuning
# Resolve the absolute path to the system-configs folder based on where the script is run from
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../system-configs"

echo "Applying High-Performance Memory Tuning..."

# Check and fix pacman lock
if [ -f /var/lib/pacman/db.lck ]; then
    echo " -> Warning: pacman database is locked."
    if ! pgrep -x pacman >/dev/null; then
        echo " -> Pacman is not actively running. Removing stale lock file..."
        sudo rm -f /var/lib/pacman/db.lck
    else
        echo " -> Error: Pacman is actively running! Please wait for it to finish."
        exit 1
    fi
fi

# 0. Install Dependencies
echo " -> Installing zRAM daemon (zram-generator)..."
sudo pacman -S --needed --noconfirm zram-generator >/dev/null

# 1. Install zRAM Generator config
echo " -> Configuring zRAM (100% RAM scale, zstd)..."
sudo mkdir -p /etc/systemd/zram-generator.conf.d/
sudo cp "$CONFIG_DIR/90-matrix-zram.conf" /etc/systemd/zram-generator.conf.d/

# 2. Install Kernel Tuning (sysctl)
echo " -> Applying Kernel Memory Routing (swappiness=150)..."
sudo cp "$CONFIG_DIR/99-matrix-sysctl.conf" /etc/sysctl.d/

# 3. Disable conflicting zswap cache
echo " -> Disabling native zswap cache..."
sudo cp "$CONFIG_DIR/matrix-zswap.conf" /etc/tmpfiles.d/

# 4. Apply Settings Immediately
echo " -> Reloading Kernel Settings & zRAM Daemon..."
sudo sysctl --system >/dev/null
sudo systemd-tmpfiles --create /etc/tmpfiles.d/matrix-zswap.conf >/dev/null
sudo systemctl daemon-reload
sudo systemctl restart systemd-zram-setup@zram0.service || true

echo "Memory Tuning module installed successfully!"
