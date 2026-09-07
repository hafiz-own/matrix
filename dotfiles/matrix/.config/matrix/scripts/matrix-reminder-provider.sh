#!/bin/bash

# DESC: Provides Walker search integration for reminders.

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

Provides Walker search integration for reminders.

Options:
  -h, --help    Show this help message and exit
EOF
}

if [[ "\${1:-}" == "-h" || "\${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi

set -euo pipefail
trap 'echo "[!] Error: Script failed on line $LINENO" >&2' ERR
# ~/.config/matrix/scripts/matrix-reminder-provider.sh
# Walker 2.x Plugin Provider

input="${1:-}"

# If no input yet, show a helpful hint
if [[ -z "$input" ]]; then
    echo '[{"label": "Type minutes then your message (e.g. 15 Take pizza out)", "exec": "", "searchable": ""}]'
    exit 0
fi

minutes=$(echo "$input" | awk '{print $1}')
message=$(echo "$input" | cut -d' ' -f2-)
[[ -z "$message" ]] || [[ "$message" == "$minutes" ]] && message="Timer complete"

if [[ "$minutes" =~ ^[0-9]+$ ]]; then
    # Provide a valid clickable action
    # We use jq to safely escape the strings for JSON
    jq -c -n \
      --arg label "󰢌 Set reminder in $minutes min: $message" \
      --arg exec "bash $HOME/.config/matrix/scripts/matrix-reminder.sh $minutes $message" \
      --arg searchable "$input" \
      '[{label: $label, exec: $exec, searchable: $searchable}]'
else
    # Error state
    echo '[{"label": "Waiting for valid minutes... (e.g. 15)", "exec": "", "searchable": ""}]'
fi
