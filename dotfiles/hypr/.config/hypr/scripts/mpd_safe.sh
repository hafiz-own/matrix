#!/bin/bash

# DESC: Central media control dispatcher.
#       - MPD is never started on boot; it lazy-starts on first keypress.
#       - Priority: MPD (if already running + active) → playerctl → start MPD fresh.
#
# Usage: mpd_safe.sh <toggle|play|pause|next|prev|previous|stop|volume <+N%|-N%>>

# ── helpers ────────────────────────────────────────────────────────────────

mpd_running() {
    pgrep -u "$USER" mpd > /dev/null 2>&1
}

mpd_ensure_running() {
    if ! mpd_running; then
        systemctl --user start mpd
        for i in $(seq 1 20); do
            mpc status > /dev/null 2>&1 && break
            sleep 0.1
        done
    fi
}

mpd_is_playing() {
    mpc status 2>/dev/null | grep -q '^\[playing\]'
}

mpd_is_paused() {
    mpc status 2>/dev/null | grep -q '^\[paused\]'
}

mpd_queue_empty() {
    [ -z "$(mpc playlist 2>/dev/null)" ]
}

playerctl_has_playing() {
    playerctl -a status 2>/dev/null | grep -q '^Playing'
}

# Lazy-start MPD, load "new" playlist, and play.
mpd_cold_start() {
    mpd_ensure_running
    if mpd_queue_empty; then
        mpc load new > /dev/null 2>&1
    fi
    mpc play > /dev/null 2>&1
}

# ── dispatch ───────────────────────────────────────────────────────────────

ACTION="${1:-toggle}"

case "$ACTION" in
    -h|--help)
        cat <<EOF
Usage: $(basename "$0") <toggle|play|pause|next|prev|stop|volume <+N%|-N%>>

Central media control — MPD priority with playerctl fallback.
MPD lazy-starts on first use; never runs on boot unless you explicitly start it.
EOF
        exit 0
        ;;

    toggle)
        if mpd_running; then
            if mpd_is_playing || mpd_is_paused; then
                mpc toggle                              # MPD active → control it
            elif ! mpd_queue_empty; then
                mpc play > /dev/null 2>&1              # MPD stopped but has queue
            elif playerctl_has_playing; then
                playerctl play-pause                   # MPD empty, playerctl active
            else
                mpd_cold_start                         # Nothing playing → start MPD
            fi
        else
            # MPD not running
            if playerctl_has_playing; then
                playerctl play-pause                   # Hand off to playerctl
            else
                mpd_cold_start                         # Nothing playing → lazy-start MPD
            fi
        fi
        ;;

    play)
        if mpd_running; then
            if mpd_is_playing; then
                : # already playing
            elif mpd_is_paused || ! mpd_queue_empty; then
                mpc play > /dev/null 2>&1
            elif playerctl_has_playing; then
                playerctl play
            else
                mpd_cold_start
            fi
        else
            if playerctl_has_playing; then
                playerctl play
            else
                mpd_cold_start
            fi
        fi
        ;;

    pause)
        if mpd_running && (mpd_is_playing || mpd_is_paused); then
            mpc pause
        else
            playerctl pause
        fi
        ;;

    next)
        if mpd_running && (mpd_is_playing || mpd_is_paused); then
            mpc next
        else
            playerctl next
        fi
        ;;

    prev|previous)
        if mpd_running && (mpd_is_playing || mpd_is_paused); then
            mpc previous
        else
            playerctl previous
        fi
        ;;

    stop)
        if mpd_running && (mpd_is_playing || mpd_is_paused); then
            mpc stop
        else
            playerctl stop
        fi
        ;;

    volume)
        # e.g. mpd_safe.sh volume +5%  or  mpd_safe.sh volume -5%
        AMOUNT="${2:?'Usage: mpd_safe.sh volume <+N%|-N%>'}"
        # Always ensure MPD is running for volume control (this is the intentional boot trigger)
        mpd_ensure_running
        if mpd_queue_empty; then
            mpc load new > /dev/null 2>&1
        fi
        mpc volume "$AMOUNT"
        ;;

    *)
        echo "[!] Unknown action: '$ACTION'" >&2
        echo "Usage: $(basename "$0") <toggle|play|pause|next|prev|stop|volume <+N%|-N%>>" >&2
        exit 1
        ;;
esac
