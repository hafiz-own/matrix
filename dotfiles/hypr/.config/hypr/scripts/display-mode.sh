#!/usr/bin/env bash
# DESC: Display mode picker (SUPER+P, Dell Fn+F8). $1 = current mode, marked
#       in the menu. The choice is applied by conf/display.lua's set_mode.

modes=("Extend" "Mirror" "External only" "Laptop only")
current=0 # walker -c takes the index of the current line
for i in "${!modes[@]}"; do [ "${modes[$i]}" = "$1" ] && current=$i; done

choice=$(printf '%s\n' "${modes[@]}" \
    | "$HOME/.config/walker/launch.sh" -d -p "Display mode" -c "$current")

case "$choice" in
    "Extend"|"Mirror"|"External only"|"Laptop only")
        hyprctl eval "local d = require('conf.display'); d.set_mode('$choice', d.external())" >/dev/null ;;
esac
