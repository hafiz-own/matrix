#!/bin/bash

# DESC: Kills the active Matrix window or application safely.

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
Usage: $(basename "$0") [OPTIONS]

Kills the active Matrix window or application safely.

Options:
  -h, --help    Show this help message and exit
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi


# If a Quickshell overlay panel is open, close it instead of killing the
# window behind it (SUPER+Q should not reach the background window).
# Only ask Quickshell when it is actually running (saves 3 IPC calls).
if pgrep -x qs >/dev/null || pgrep -x quickshell >/dev/null; then
    for panel in sidebar wallpaper calendar; do
        if [ "$(qs ipc call "$panel" isOpen 2>/dev/null)" = "true" ]; then
            qs ipc call "$panel" close
            exit 0
        fi
    done
fi

# Closing with no focused window is a no-op, so dispatch directly.
hyprctl dispatch 'hl.dsp.window.close()'
