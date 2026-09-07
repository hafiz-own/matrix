#!/usr/bin/env bash

# DESC: Interactive master installer for the Matrix Ecosystem.

# Fail fast, fail loud
set -Eeuo pipefail
trap 'echo -e "\e[31m[!] Error: Installation aborted. A command failed on line $LINENO.\e[0m" >&2' ERR

# Standard logging functions
info()    { echo -e "\e[34m[*]\e[0m $1"; }
warn()    { echo -e "\e[33m[!]\e[0m $1"; }
die()     { echo -e "\e[31m[✘]\e[0m $1" >&2; exit 1; }
success() { echo -e "\e[32m[✔]\e[0m $1"; }

# Help Menu
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Interactive master installer for the Matrix Ecosystem. Scans the 'installers' directory
and provides a TUI (gum) interface to selectively install components.

Options:
  -h, --help    Show this help message and exit
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi

# Ensure gum is installed
if ! command -v gum &> /dev/null; then
    echo "Error: 'gum' is not installed. Please install it first (paru -S gum)."
    exit 1
fi

# Resolve the absolute path to this script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLERS_DIR="$SCRIPT_DIR/installers"

if [ ! -d "$INSTALLERS_DIR" ]; then
    echo "Error: installers directory not found at $INSTALLERS_DIR"
    exit 1
fi

echo "=============================================="
echo "    Matrix Ecosystem Provisioning System      "
echo "=============================================="
echo ""

# 1. Build the menu list dynamically
declare -a MENU_OPTIONS=()

for script in $(ls "$INSTALLERS_DIR"/*.sh | sort); do
    filename=$(basename "$script")
    
    # Extract the custom # DESC: line if it exists
    desc=$(grep -m 1 "^# DESC:" "$script" | sed 's/^# DESC: //' || true)
    
    if [ -z "$desc" ]; then
        desc="No description provided"
    fi
    
    # Format the string for gum. E.g., "01-system-tuning.sh  |  CPU and Disk I/O Tuning"
    MENU_OPTIONS+=("$filename  |  $desc")
done

# 2. Prompt the user using Gum
echo "Select the modules you wish to install:"
echo " (Use Space to toggle, Enter to confirm)"
echo ""

# Temporarily disable set -e so the script doesn't crash if the user hits ESC
set +e
SELECTED_MODULES=$(printf "%s\n" "${MENU_OPTIONS[@]}" | gum choose --no-limit --cursor="➜ " --selected-prefix="◉ " --unselected-prefix="◯ " --header="")
set -e

# If nothing was selected or user aborted
if [ -z "$SELECTED_MODULES" ]; then
    echo "No modules selected or process aborted."
    exit 0
fi

echo ""
echo "Starting installation process..."
echo ""

# 3. Parse the selections and run the corresponding scripts
while read -u 3 -r line; do
    # Skip empty lines
    [ -z "$line" ] && continue
    
    # Extract just the filename (everything before "  |  ")
    filename=$(echo "$line" | awk -F '  \\|  ' '{print $1}')
    script_path="$INSTALLERS_DIR/$filename"
    
    if [ -f "$script_path" ]; then
        echo "----------------------------------------------"
        gum style --foreground 212 "Executing module: $filename"
        echo "----------------------------------------------"
        bash "$script_path"
    else
        echo "Error: Script $filename not found!"
    fi
done 3<<< "$SELECTED_MODULES"

echo ""
echo "=============================================="
echo "     Welcome to the charms of The Matrix      "
echo "=============================================="
