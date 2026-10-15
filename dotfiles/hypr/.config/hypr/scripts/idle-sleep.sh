#!/usr/bin/env bash
# DESC: hypridle helper — sleep after long idle, depending on power source.
#   idle-sleep.sh battery   hibernate, but only when running on battery
#   idle-sleep.sh ac        suspend, but only when on AC power
# A machine without a battery counts as AC.

on_ac() {
    local supply
    for supply in /sys/class/power_supply/*; do
        [[ "$(<"$supply/type")" == "Mains" && "$(<"$supply/online")" == "1" ]] && return 0
    done
    # No Mains supply online: on battery if a battery exists, else AC (desktop)
    ! compgen -G "/sys/class/power_supply/BAT*" >/dev/null
}

case "${1:-}" in
    battery) on_ac || systemctl hibernate ;;
    ac)      on_ac && systemctl suspend ;;
    *)       echo "Usage: $0 battery|ac" >&2; exit 1 ;;
esac
exit 0
