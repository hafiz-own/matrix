#!/usr/bin/env bash
# matrix-screenrecord-status.sh

# DESC: Returns the current screen recording status for Waybar.

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

Returns the current screen recording status for Waybar.

Options:
  -h, --help    Show this help message and exit
EOF
}

if [[ "\${1:-}" == "-h" || "\${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi


if pgrep -f "^gpu-screen-recorder" >/dev/null; then
    # Return a JSON object for Waybar with a simple circle icon and class for styling
    echo '{"text": " ", "class": "recording", "tooltip": "Screen recording is active\nClick to stop"}'
else
    # Return empty string so Waybar hides the module
    echo '{"text": "", "class": "", "tooltip": ""}'
fi
