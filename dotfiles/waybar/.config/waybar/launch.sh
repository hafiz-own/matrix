#!/usr/bin/env bash
#                    __
#  _    _____ ___ __/ /  ___ _____
# | |/|/ / _ `/ // / _ \/ _ `/ __/
# |__,__/\_,_/\_, /_.__/\_,_/_/
#            /___/
#
# (Re)start waybar with the selected theme, or stop it when
# ~/.config/matrix/settings/waybar-disabled exists.
# Waybar normally runs as waybar.service (theme resolved by start.sh);
# without the session target it falls back to a plain background process.

# -----------------------------------------------------
# Prevent duplicate launches: only the first parallel
# invocation proceeds; all others exit immediately.
# -----------------------------------------------------
lock_file="$XDG_RUNTIME_DIR/waybar-launch.lock"
exec 200>"$lock_file"
flock -n 200 || exit 0

disabled="$HOME/.config/matrix/settings/waybar-disabled"

if systemctl --user -q is-active graphical-session.target; then
    if [ -f "$disabled" ]; then
        echo ":: Waybar disabled"
        systemctl --user stop waybar.service
    else
        systemctl --user restart waybar.service
    fi
    exit 0
fi

# -----------------------------------------------------
# Fallback: no systemd session -> manage the process directly
# -----------------------------------------------------
pkill -x waybar
for _ in {1..60}; do pgrep -x waybar >/dev/null || break; sleep 0.05; done
pkill -9 -x waybar 2>/dev/null   # still alive after 3s: force it

if [ -f "$disabled" ]; then
    echo ":: Waybar disabled"
else
    # Close the lock fd for the child so it does not hold the lock
    setsid "$HOME/.config/waybar/start.sh" 200>&- &
fi
