#!/usr/bin/env bash
# DESC: hypridle helper — hibernate after long idle, but only on battery.
#       On AC the session just stays locked with the display off.
for supply in /sys/class/power_supply/*; do
    [[ "$(<"$supply/type")" == "Mains" ]] || continue
    [[ "$(<"$supply/online")" == "1" ]] && exit 0   # on AC: do nothing
done
# No mains supply online. Only hibernate when there is a battery
# (a desktop without a battery reports no Mains supply at all).
compgen -G "/sys/class/power_supply/BAT*" >/dev/null || exit 0
systemctl hibernate
