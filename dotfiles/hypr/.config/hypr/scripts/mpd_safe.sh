#!/bin/bash

# DESC: Safely initializes and controls the Music Player Daemon (MPD).

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

Safely initializes and controls the Music Player Daemon (MPD).

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
# Start mpd if not already running, then run the mpc command
if ! pgrep -u "$USER" mpd > /dev/null 2>&1; then
    systemctl --user start mpd
    # Wait until mpd is ready to accept connections
    for i in $(seq 1 20); do
        mpc status > /dev/null 2>&1 && break
        sleep 0.1
    done
fi

# Load "new" playlist if queue is empty
if [ -z "$(mpc playlist 2>/dev/null)" ]; then
    mpc load new > /dev/null 2>&1
    # If the user's intent was to play/toggle, we need to manually trigger play
    # because 'mpc toggle' on an empty queue does nothing, but after load it will just pause if we don't start it.
    if [[ "$*" == *"toggle"* ]] || [[ "$*" == *"play"* ]]; then
        mpc play > /dev/null 2>&1
        exit 0
    fi
fi

mpc "$@"
