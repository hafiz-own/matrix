#!/usr/bin/env bash
# DESC: Battery line for hyprlock. Finds the first BAT* supply; prints
#       nothing (label hidden) on machines without a battery.
for bat in /sys/class/power_supply/BAT*; do
    [[ -r "$bat/capacity" ]] || continue
    printf '%s     %s%%\n' "$(<"$bat/status")" "$(<"$bat/capacity")"
    exit 0
done
