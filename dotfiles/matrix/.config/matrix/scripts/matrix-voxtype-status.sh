#!/bin/bash

# DESC: Provides Voxtype audio transcription status for Waybar.

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

Provides Voxtype audio transcription status for Waybar.

Options:
  -h, --help    Show this help message and exit
EOF
}

if [[ "\${1:-}" == "-h" || "\${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi


# matrix-voxtype-status.sh
# Waybar module script that monitors Voxtype's state file using tail -F

STATE_FILE="$XDG_RUNTIME_DIR/voxtype/state"

# Ensure the state file exists before tailing it
mkdir -p "$(dirname "$STATE_FILE")"
touch "$STATE_FILE"

# Parse the state and print JSON for Waybar
print_state() {
  local state="$1"
  if [[ "$state" == "recording" ]]; then
    # Microphone icon, red text (via class)
    echo '{"text": "", "class": "recording"}'
  elif [[ "$state" == "transcribing" ]]; then
    # Spinner or distinct icon for transcribing
    echo '{"text": "", "class": "transcribing"}'
  else
    # Idle/hidden
    echo '{"text": "", "class": "idle"}'
  fi
}

# Print initial state
print_state "$(cat "$STATE_FILE")"

# Tail the file efficiently (blocks and uses 0% CPU until file changes)
tail -F "$STATE_FILE" 2>/dev/null | while read -r line; do
  print_state "$line"
done
