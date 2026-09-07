#!/bin/bash

# DESC: Installs the Matrix Reminder desktop application and dependencies.

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

Installs the Matrix Reminder desktop application and dependencies.

Options:
  -h, --help    Show this help message and exit
EOF
}

if [[ "\${1:-}" == "-h" || "\${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi

set -euo pipefail
# 06-reminder-setup.sh
# DESC: Matrix Walker Reminder App


echo "Deploying Matrix Reminder Desktop Application..."

# Create the applications directory if it doesn't exist
mkdir -p ~/.local/share/applications/

# Dynamically inject the correct home path into the desktop file
sed "s|/home/own|$HOME|g" ~/.config/matrix/scripts/system-configs/matrix-reminder.desktop > ~/.local/share/applications/matrix-reminder.desktop

# Update the desktop database so Walker immediately discovers it
update-desktop-database ~/.local/share/applications/

echo "Matrix Reminder successfully deployed!"
