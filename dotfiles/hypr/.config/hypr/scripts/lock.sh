#!/usr/bin/env bash
# DESC: The one lock path (hypridle lock_cmd; SUPER+CTRL+L and matrix-power
#       go through `loginctl lock-session`, which runs this).
#       Pauses media, then starts hyprlock.
#
# Right after an unlock, the old hyprlock can still be alive for a moment
# while it stops fingerprint verification and releases the reader. A plain
# `pidof hyprlock || hyprlock` then does nothing (the "press twice" bug),
# and a new instance started too early cannot claim the reader (no
# fingerprint prompt). So wait for an exiting instance first. While the
# screen is really locked the lock keybinds cannot fire, and an extra
# lock-session from hypridle just times out here and does nothing.

playerctl --all-players pause 2>/dev/null
mpc -q pause 2>/dev/null

for _ in {1..30}; do                       # up to 3s
    pidof -q hyprlock || exec hyprlock
    sleep 0.1
done
exit 0                                     # still running: genuinely locked
