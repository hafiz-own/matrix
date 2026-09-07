#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────
# Walker Dictionary Lookup (called with a word argument)
# ──────────────────────────────────────────────────────────
# Usage: dictionary-lookup.sh "apple"
# Skips the input step since the word is already known.
# Shows: dictionary picker → definition → copy to clipboard
# ──────────────────────────────────────────────────────────

DICT_DIR="$HOME/.stardict/dic"
WALKER_THEME="matrix-minimal"
WORD="$1"

# Trim whitespace
WORD=$(echo "$WORD" | xargs)
[[ -z "$WORD" ]] && exit 0

# Check sdcv
if ! command -v sdcv &>/dev/null; then
    notify-send "󰂺 Dictionary" "sdcv not installed. Run: sudo pacman -S sdcv" -i dialog-error
    exit 1
fi

# ── Query all dictionaries (JSON) ────────────────────────
RAW_JSON=$(sdcv -n --utf8-output --json-output --data-dir "$DICT_DIR" "$WORD" 2>/dev/null)

if [[ -z "$RAW_JSON" ]] || [[ "$RAW_JSON" == "[]" ]]; then
    notify-send "󰂺 Dictionary" "No definition found for '$WORD'" -i dialog-information -t 3000
    exit 0
fi

# Extract unique dictionary names
DICT_LIST=$(echo "$RAW_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
seen = []
for entry in data:
    d = entry.get('dict', 'Unknown')
    if d not in seen:
        seen.append(d)
for d in seen:
    name = d.replace('dictd_www.dict.org_', '').replace('dictd_www.mova.org_', '')
    name = name.replace('stardict-', '').replace('_', ' ')
    print(f'{name}  │  {d}')
")

[[ -z "$DICT_LIST" ]] && exit 0

# ── Pick a dictionary ────────────────────────────────────
PICKED=$(echo "$DICT_LIST" | walker --dmenu \
    --placeholder "󰂺  '$WORD' — pick a dictionary" \
    --theme "$WALKER_THEME" \
    2>/dev/null)

[[ -z "$PICKED" ]] && exit 0

DICT_NAME=$(echo "$PICKED" | sed 's/.*│  //')

# ── Show definition ──────────────────────────────────────
DEFINITION=$(echo "$RAW_JSON" | python3 -c "
import json, sys, textwrap
data = json.load(sys.stdin)
target = sys.argv[1]
wrapper = textwrap.TextWrapper(width=80, break_long_words=False, break_on_hyphens=False)
for entry in data:
    if entry.get('dict') == target:
        defn = entry.get('definition', '')
        for line in defn.strip().splitlines():
            line = line.strip()
            if line:
                print(wrapper.fill(line))
        break
" "$DICT_NAME")

[[ -z "$DEFINITION" ]] && exit 0

SELECTED=$(echo "$DEFINITION" | walker --dmenu \
    --placeholder "󰂺  $WORD — select to copy" \
    --theme "$WALKER_THEME" \
    2>/dev/null)

if [[ -n "$SELECTED" ]]; then
    echo -n "$SELECTED" | wl-copy
    notify-send "󰂺 Dictionary" "Copied to clipboard" -i edit-copy -t 2000
fi
