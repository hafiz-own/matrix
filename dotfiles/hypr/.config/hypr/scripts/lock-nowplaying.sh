#!/usr/bin/env bash
# DESC: Now-playing block for hyprlock (title / artist / synced lyric).
#       One mpc call per refresh; prints nothing unless MPD is playing.
#       Output is Pango markup for a single hyprlock label.

MUSIC_DIR="$HOME/Music/some_good_time"

out=$(mpc -f '%file%|%title%|%artist%' 2>/dev/null) || exit 0
[[ "$out" == *"[playing]"* ]] || exit 0

{ IFS='|' read -r file title artist; read -r status; } <<<"$out"

esc() {
    local s=${1//&/"&amp;"}
    s=${s//</"&lt;"}
    printf '%s' "${s//>/"&gt;"}"
}

printf "<span size='20pt' alpha='90%%' weight='bold'>%s</span>\n" "$(esc "$title")"
printf "<span size='14pt' alpha='60%%'>%s</span>" "$(esc "$artist")"

# Synced lyric line (only when lyrics are toggled on and an .lrc exists)
[[ -f /tmp/lyrics_enabled ]] || exit 0
lrc="$MUSIC_DIR/${file%.*}.lrc"
[[ -f "$lrc" ]] || exit 0
[[ "$status" =~ ([0-9]+):([0-9]+)/ ]] || exit 0
elapsed=$((10#${BASH_REMATCH[1]} * 60 + 10#${BASH_REMATCH[2]}))

line=$(awk -v t="$elapsed" -v best=-1 '
    match($0, /^\[([0-9]+):([0-9]+(\.[0-9]+)?)\]/) {
        split(substr($0, 2, RLENGTH - 2), p, ":")
        ts = p[1] * 60 + p[2]
        txt = substr($0, RLENGTH + 1)
        gsub(/^[ \t]+|[ \t\r]+$/, "", txt)
        if (ts <= t && ts >= best && txt != "") { best = ts; cur = txt }
    }
    END { print cur }' "$lrc")

[[ -n "$line" ]] && printf "\n\n<span size='16pt' alpha='75%%'>%s</span>" "$(esc "$line")"
exit 0
