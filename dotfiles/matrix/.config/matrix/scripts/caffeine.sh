#!/bin/bash

# DESC: Toggles the screen idle inhibitor (caffeine mode).

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

Toggles the screen idle inhibitor (caffeine mode).

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
SERVICE="hypridle"

print_status() {
    # If hypridle is running, the system will sleep normally. So "Stay Awake" is OFF.
    if pgrep -x "$SERVICE" >/dev/null ; then
        # Output empty JSON so the module hides completely
        echo '{"text": "", "class": "notactive", "tooltip": ""}'
    else
        # If hypridle is NOT running, "Stay Awake" is ON.
        echo '{"text": "☕", "class": "active", "tooltip": "Stay Awake ON (Screen will not sleep)\nClick to allow sleep"}'
    fi
}

case "$1" in
    status)
        print_status
        ;;
    toggle)
        if pgrep -x "$SERVICE" >/dev/null ; then
            # It was running, kill it to stay awake
            killall "$SERVICE"
            notify-send -a "Matrix" -u low "☕ Stay Awake Enabled" "Screen sleep disabled."
        else
            # It was not running, start it to allow sleep
            "$SERVICE" &
            notify-send -a "Matrix" -u low "󰤄 Stay Awake Disabled" "Screen will sleep normally."
        fi
        # Tell Waybar to instantly refresh module 9 (which we assigned to custom/hypridle)
        pkill -RTMIN+9 waybar
        ;;
    *)
        echo "Usage: $0 {status|toggle}"
        exit 1
        ;;
esac
