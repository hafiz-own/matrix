#!/bin/bash

# DESC: Backend script for processing scheduled reminders.

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

Backend script for processing scheduled reminders.

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

minutes="$1"
shift
message="$*"

if [[ ! "$minutes" =~ ^[0-9]+$ ]] || (( minutes == 0 )); then
    notify-send -u critical -a "Matrix Reminder" "Reminder Error" "First argument must be a number of minutes."
    exit 1
fi

if [[ -z "$message" ]]; then
    message="Your ${minutes} minutes are up!"
fi

set_at=$(date +%s)
remind_at=$(date -d "+${minutes} minutes" +%H:%M)
unit="matrix-reminder-${minutes}m-$set_at"

# Spawn the systemd timer
systemd-run --user --quiet --collect --on-active="${minutes}m" --unit="$unit" \
    bash -c "notify-send -u critical -a 'Matrix Reminder' '󰢌 Reminder' '$message'"

# Confirm creation
notify-send -a "Matrix Reminder" "Reminder Set" "You'll be reminded at $remind_at: $message"
