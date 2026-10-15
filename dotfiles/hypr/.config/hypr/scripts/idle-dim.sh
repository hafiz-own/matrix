#!/usr/bin/env bash
# DESC: hypridle helper — dim the screen before the screensaver, restore on activity.
# Usage: idle-dim.sh dim|restore
DIM_TO=10   # percent

case "${1:-}" in
    dim)
        brightnessctl -q -s >/dev/null   # always save, so restore never brings back a stale value
        current=$(brightnessctl -m | cut -d, -f4)
        (( ${current%\%} > DIM_TO )) && brightnessctl -q set "${DIM_TO}%" >/dev/null
        ;;
    restore)
        brightnessctl -q -r >/dev/null
        ;;
    *)
        echo "Usage: $0 dim|restore" >&2
        exit 1
        ;;
esac
