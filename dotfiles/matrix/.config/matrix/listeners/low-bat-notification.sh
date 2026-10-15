#!/usr/bin/env bash
# DESC: Low-battery notifications (20% normal, 15% critical), event-driven.
#
# Listens to UPower's PropertiesChanged signals for the battery (UPower
# already polls the hardware; we only wake when Percentage/State change)
# instead of a bash loop that woke every 60s. Values are read from sysfs
# with bash builtins, so an event costs no extra processes.
# Runs as low-battery.service (systemd user unit, graphical session).

source "$HOME/.config/matrix/scripts/matrix-notification-handler"

APP_NAME="System"
NOTIFICATION_ICON="battery-low-symbolic"

BAT=$(compgen -G "/sys/class/power_supply/BAT*" | head -n 1)
[[ -n "$BAT" ]] || exit 0
UPOWER_BAT="/org/freedesktop/UPower/devices/battery_${BAT##*/}"

NOTIFIED_20=false
NOTIFIED_15=false

check() {
    local capacity status
    read -r capacity <"$BAT/capacity"
    read -r status <"$BAT/status"
    if [[ "$status" != "Discharging" ]] || (( capacity > 20 )); then
        NOTIFIED_20=false
        NOTIFIED_15=false
        return
    fi
    if (( capacity <= 15 )) && [[ $NOTIFIED_15 == false ]]; then
        notify_user --u "critical" --a "$APP_NAME" --i "$NOTIFICATION_ICON" \
            --s "Battery Low" --m "Remaining: ${capacity}%"
        NOTIFIED_15=true
        NOTIFIED_20=true
    elif (( capacity > 15 )) && [[ $NOTIFIED_20 == false ]]; then
        notify_user --u "normal" --a "$APP_NAME" --i "$NOTIFICATION_ICON" \
            --s "Battery Low" --m "Remaining: ${capacity}%"
        NOTIFIED_20=true
    fi
}

check
gdbus monitor --system --dest org.freedesktop.UPower --object-path "$UPOWER_BAT" |
while read -r line; do
    [[ "$line" == *"'Percentage'"* || "$line" == *"'State'"* ]] && check
done
