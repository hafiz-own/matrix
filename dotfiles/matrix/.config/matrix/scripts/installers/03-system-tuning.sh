#!/usr/bin/env bash

# DESC: Applies low-level system tuning and performance enhancements.

# Fail fast, fail loud
set -Eeuo pipefail
trap 'echo -e "\e[31m[!] Error: Script failed on line $LINENO\e[0m" >&2' ERR

# Standard logging functions
info()    { echo -e "\e[34m[*]\e[0m $1"; }
warn()    { echo -e "\e[33m[!]\e[0m $1"; }
die()     { echo -e "\e[31m[✘]\e[0m $1" >&2; exit 1; }
success() { echo -e "\e[32m[✔]\e[0m $1"; }

# Help Menu
show_help() {
    cat << EOF
Usage: \$(basename "\$0") [OPTIONS]

Applies low-level system tuning and performance enhancements.

Options:
  -h, --help    Show this help message and exit
EOF
}

if [[ "\${1:-}" == "-h" || "\${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi


set -euo pipefail

# DESC: CPU and Disk I/O Tuning
# Resolve the absolute path to the system-configs folder based on where the script is run from
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../system-configs"

echo "Applying System Tuning Configurations..."

# 1. Install OOM Protection (Matrix Global Rule)
echo " -> Installing OOM Daemon Protection..."
sudo mkdir -p /etc/systemd/oomd.conf.d/
sudo cp "$CONFIG_DIR/10-matrix-oomd.conf" /etc/systemd/oomd.conf.d/
sudo systemctl enable --now systemd-oomd.service

# 2. Install PAM Faillock Rules
echo " -> Installing PAM Faillock Rule (10 attempts)..."
sudo cp "$CONFIG_DIR/matrix-faillock.conf" /etc/security/faillock.conf

echo "System Tuning module installed successfully!"
