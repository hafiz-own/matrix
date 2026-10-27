#!/usr/bin/env bash
# DESC: Display mode picker (SUPER+P, Dell Fn+F8). $1 = current mode, marked
#       in the menu. The choice is applied by conf/display.lua's set_mode.

choice=$(printf '%s\n' "Extend" "Mirror" "External only" "Laptop only" \
    | "$HOME/.config/walker/launch.sh" -d -p "Display mode" -c "$1")

case "$choice" in
    "Extend"|"Mirror"|"External only"|"Laptop only")
        hyprctl eval "local d = require('conf.display'); d.set_mode('$choice', d.external())" >/dev/null ;;
esac
