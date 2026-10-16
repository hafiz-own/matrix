#!/bin/bash
# matrix-screensaver.sh: A bouncer script to defeat the Wayland mapping pointer-enter event flaw

# DESC: Activates the Matrix terminal screensaver.

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

Activates the Matrix terminal screensaver.

Options:
  -h, --help    Show this help message and exit
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi


TIME_FILE="/tmp/matrix_screensaver_start"

if [ "${1:-}" == "start" ]; then
    # Prevent multiple instances
    if pgrep -f "^kitty --class matrix-screensaver" >/dev/null; then
        exit 0
    fi
    
    # Record start time (nanoseconds)
    date +%s%N > "$TIME_FILE"
    
    # One screensaver per monitor: Hyprland places each window on its
    # monitor via the exec rule; the matrix-screensaver window rule makes it
    # fullscreen. Extra screens cost one kitty + cmatrix each, only while
    # the screensaver runs.
    for mon in $(hyprctl monitors -j | jq -r '.[].name'); do
        hyprctl dispatch "hl.dsp.exec_cmd(\"kitty --class matrix-screensaver -e cmatrix -b -s\", { monitor = \"$mon\" })" >/dev/null
    done
    
elif [ "${1:-}" == "stop" ]; then
    # If the screensaver is not running, do nothing
    if ! pgrep -f "^kitty --class matrix-screensaver" >/dev/null; then
        exit 0
    fi

    # Check elapsed time
    START_TIME=$(cat "$TIME_FILE" 2>/dev/null || echo 0)
    NOW=$(date +%s%N)
    DIFF=$((NOW - START_TIME))
    
    # If elapsed time is less than 500,000,000 ns (0.5 seconds), ignore it.
    if [ "$DIFF" -gt 500000000 ]; then
        pkill -f "^kitty --class matrix-screensaver"
    else
        echo "Ignored early stop request (fake Wayland event)." >> /tmp/matrix_screensaver_debug.log
    fi
else
    echo "Usage: $0 {start|stop}"
    exit 1
fi
