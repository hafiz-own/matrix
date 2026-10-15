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

# Caffeine holds a systemd idle inhibitor instead of killing hypridle, so
# hypridle keeps running (and keeps its lock-before-sleep hook). hypridle
# honours systemd inhibitors unless ignore_systemd_inhibit is set.
PID_FILE="${XDG_RUNTIME_DIR:-/run/user/$UID}/caffeine.pid"

is_on() {
    [[ -f "$PID_FILE" ]] && kill -0 "$(<"$PID_FILE")" 2>/dev/null
}

print_status() {
    if is_on; then
        echo '{"text": "☕", "class": "active", "tooltip": "Stay Awake ON (screen will not dim, lock or sleep)\nClick to allow sleep"}'
    else
        # Empty text hides the module
        echo '{"text": "", "class": "notactive", "tooltip": ""}'
    fi
}

case "${1:-}" in
    status)
        print_status
        ;;
    toggle)
        if is_on; then
            kill "$(<"$PID_FILE")" 2>/dev/null || true
            rm -f "$PID_FILE"
            notify-send -a "Matrix" -u low "󰤄 Stay Awake Disabled" "Screen will sleep normally."
        else
            setsid systemd-inhibit --what=idle --who=caffeine --why="Stay awake" \
                sleep infinity >/dev/null 2>&1 &
            echo $! >"$PID_FILE"
            notify-send -a "Matrix" -u low "☕ Stay Awake Enabled" "Screen sleep disabled."
        fi
        # Refresh the waybar custom/hypridle module (signal 9)
        pkill -RTMIN+9 waybar || true
        ;;
    *)
        echo "Usage: $0 {status|toggle}"
        exit 1
        ;;
esac
