#!/usr/bin/env bash

# DESC: Toggles Hyprland animations on and off globally.

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

Toggles Hyprland animations on and off globally.

Options:
  -h, --help    Show this help message and exit
EOF
}

if [[ "\${1:-}" == "-h" || "\${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi

cache_file="$HOME/.cache/toggle_animation"
if [[ $(cat $HOME/.config/hypr/conf/animation.lua) == *"disabled"* ]]; then
    echo ":: Toggle blocked by disabled.conf variation."
else
    if [ -f $cache_file ]; then
        hyprctl keyword animations:enabled true
        rm $cache_file
    else
        hyprctl keyword animations:enabled false
        touch $cache_file
    fi
fi
