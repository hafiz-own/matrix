#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────
# Walker Dictionary Plugin (sdcv / StarDict Integration)
# High-Performance State Machine
# ──────────────────────────────────────────────────────────
# 3-step flow:
#   1. Type a word (minimal search bar)
#   2. Pick which dictionary to read from
#   3. See the full definition, select a line to copy
#
# Navigation: Pressing ESC drops you back to the previous step.
# ──────────────────────────────────────────────────────────

DICT_DIR="$HOME/.stardict/dic"
# Read active theme dynamically, fallback to spotlight-clean if missing
read -r WALKER_THEME < "$HOME/.config/matrix/settings/walker-theme" 2>/dev/null || WALKER_THEME="matrix-minimal"
if [ -z "$WALKER_THEME" ]; then
    WALKER_THEME="matrix-minimal"
fi
TMP_JSON="/tmp/walker_dict.json"

# Check sdcv is available
if ! command -v sdcv &>/dev/null; then
    notify-send "Dictionary" "sdcv is not installed. Run: sudo pacman -S sdcv" -i dialog-error
    exit 1
fi

while true; do
    # ── State 1: Search Bar ─────────────────────────────────────
    WORD=$(walker --dmenu --inputonly \
        --placeholder "Define a word..." \
        --theme "$WALKER_THEME" \
        2>/dev/null)
    
    WORD=$(echo "$WORD" | xargs)
    
    # If user presses ESC or inputs nothing, exit entirely
    [[ -z "$WORD" ]] && exit 0

    while true; do
        # ── State 2: Dictionary List ────────────────────────────────
        # Fetch definitions rapidly and save safely to file (bypassing bash memory limits/null bytes)
        sdcv -n --utf8-output --json-output --data-dir "$DICT_DIR" "$WORD" > "$TMP_JSON" 2>/dev/null
        
        # If no result, notify and drop back to search bar
        if [[ ! -s "$TMP_JSON" ]] || grep -q '^\[\]$' "$TMP_JSON"; then
            notify-send "Dictionary" "No definition found for '$WORD'" -i dialog-information -t 3000
            break
        fi
        
        # Extract unique dictionaries into a safe bash array
        mapfile -t RAW_DICTS < <(jq -r '[.[].dict] | unique | .[]' "$TMP_JSON")
        
        # Build the menu list string
        MENU_LIST="󰁆 Back (Search new word)\n"
        for raw_dict in "${RAW_DICTS[@]}"; do
            clean_name=$(echo "$raw_dict" | sed -e 's/dictd_www\.dict\.org_//g' -e 's/dictd_www\.mova\.org_//g' -e 's/stardict-//g' -e 's/_/ /g')
            MENU_LIST+=" $clean_name\n"
        done
        
        # We use --index to get the array index, bypassing string parsing entirely!
        PICKED_INDEX=$(echo -e "$MENU_LIST" | walker --dmenu --index \
            --placeholder "'$WORD' found in these dictionaries..." \
            --theme "$WALKER_THEME" \
            2>/dev/null)
            
        # If user presses ESC, halt the entire workflow
        [[ -z "$PICKED_INDEX" ]] && exit 0
        
        # If user clicks the Back item (Index 0), drop back to search bar
        if [[ "$PICKED_INDEX" -eq 0 ]]; then
            break 
        fi
        
        # Extract dictionary name safely using array lookup
        DICT_INDEX=$((PICKED_INDEX - 1))
        DICT_NAME="${RAW_DICTS[$DICT_INDEX]}"
        
        while true; do
            # ── State 3: Definition View ────────────────────────────────
            # Parse target dictionary definition directly from file
            RAW_DEFINITION=$(jq -r --arg d "$DICT_NAME" '.[] | select(.dict == $d) | .definition' "$TMP_JSON")
            
            # Escape XML/Pango characters to prevent GTK rendering from silently failing and dropping the rows
            RAW_DEFINITION=$(echo "$RAW_DEFINITION" | sed -e 's/&/&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')
            
            # Wrap text beautifully at 75 columns so it never truncates horizontally in Walker
            # We use `fmt -s` because it is UTF-8 character aware, unlike `fold` which splits bytes and crashes GTK
            WRAPPED_DEFINITION=$(echo "$RAW_DEFINITION" | fmt -s -w 75)
            
            # Strip completely empty lines, as Walker's dmenu mode often treats them as End-Of-File (EOF) and drops all subsequent text
            WRAPPED_DEFINITION=$(echo "$WRAPPED_DEFINITION" | grep -v '^[[:space:]]*$')
            
            # The "Quote Block" UI Engine
            # This prepends a sleek vertical bar and indentation to every line of the definition,
            # visually grouping the fragmented rows into a cohesive, readable document block.
            PREFIX="   ┃  "
            STYLED_DEFINITION=$(echo "$WRAPPED_DEFINITION" | sed "s/^/$PREFIX/")
            
            # We don't use --index here because we WANT the literal string to copy
            SELECTED=$( (echo "󰁆 Back (Choose another dictionary)"; echo "󰆏 Copy Entire Definition"; echo "$STYLED_DEFINITION") | walker --dmenu \
                --placeholder "$WORD — select to copy" \
                --theme "$WALKER_THEME" \
                2>/dev/null)
                
            # If user presses ESC, halt the entire workflow
            [[ -z "$SELECTED" ]] && exit 0
            
            # If user clicks the Back item, drop back to Dictionary List
            if [[ "$SELECTED" == "󰁆 Back"* ]]; then
                break 
            fi
            
            # If user clicks Copy Entire, copy the UNWRAPPED RAW definition
            if [[ "$SELECTED" == "󰆏 Copy Entire Definition" ]]; then
                # Un-escape the XML characters before copying so the user gets clean text
                CLEAN_DEF=$(echo "$RAW_DEFINITION" | sed -e 's/&amp;/\&/g' -e 's/&lt;/</g' -e 's/&gt;/>/g')
                echo -n "$CLEAN_DEF" | wl-copy
                notify-send "Dictionary" "Entire definition copied" -i edit-copy -t 2000
                exit 0
            fi
            
            # If user selects a real definition line, copy and exit completely
            # Un-escape the XML characters and strip the visual indentation prefix
            CLEAN_SEL=$(echo "$SELECTED" | sed -e "s/^$PREFIX//" -e 's/&amp;/\&/g' -e 's/&lt;/</g' -e 's/&gt;/>/g')
            echo -n "$CLEAN_SEL" | wl-copy
            notify-send "Dictionary" "Line copied to clipboard" -i edit-copy -t 2000
            exit 0
        done
    done
done
