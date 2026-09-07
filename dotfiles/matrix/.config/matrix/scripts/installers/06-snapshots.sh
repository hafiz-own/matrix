#!/usr/bin/env bash
# ~/.config/matrix/scripts/installers/04-snapshots.sh
# DESC: BTRFS System Snapshots Setup

# DESC: Configures BTRFS snapshots using Snapper and integrates them with pacman hooks.

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

Configures BTRFS snapshots using Snapper and integrates them with pacman hooks.

Options:
  -h, --help    Show this help message and exit
EOF
}

if [[ "\${1:-}" == "-h" || "\${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi


set -euo pipefail

# Resolve the absolute path to the system-configs folder
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../system-configs"

echo "Applying Event-Driven Btrfs Snapshot Architecture..."

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

# 1. Ensure all necessary snapshot dependencies are installed
echo " -> Installing dependencies (snapper, snap-pac, grub-btrfs, inotify-tools)..."
sudo pacman -S --needed --noconfirm snapper snap-pac grub-btrfs inotify-tools >/dev/null

# 2. Initialize Snapper on Root if it doesn't exist
if [[ ! -f /etc/snapper/configs/root ]]; then
    echo " -> Initializing snapper on the root filesystem..."
    sudo mkdir -p /etc/snapper/configs
    sudo snapper --no-dbus -c root create-config / >/dev/null 2>&1 || sudo snapper -c root create-config / >/dev/null
fi

# 3. Apply the strict Matrix Snapper configuration template
echo " -> Applying strict Matrix snapshot retention policy (Limit 5)..."
sudo cp "$CONFIG_DIR/matrix-snapper-root" /etc/snapper/configs/root
sudo chmod 0644 /etc/snapper/configs/root

# Tell snapper that 'root' is our active configuration
sudo mkdir -p /etc/conf.d
echo 'SNAPPER_CONFIGS="root"' | sudo tee /etc/conf.d/snapper >/dev/null
sudo chmod 0644 /etc/conf.d/snapper

# 4. Configure Systemd Timers (Disable Timeline, Enable Cleanup)
echo " -> Optimizing background timers..."
sudo systemctl disable --now snapper-timeline.timer >/dev/null 2>&1 || true
sudo systemctl enable --now snapper-cleanup.timer >/dev/null 2>&1 || true

# 5. Enable GRUB Btrfs integration
echo " -> Enabling automatic GRUB bootloader synchronization..."
sudo systemctl enable --now grub-btrfsd.service >/dev/null 2>&1 || true

echo "Snapshot module installed successfully! Your system will now automatically back itself up before any package updates."
