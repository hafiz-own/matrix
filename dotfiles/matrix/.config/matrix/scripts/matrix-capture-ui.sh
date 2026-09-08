#!/usr/bin/env bash
# matrix-capture-ui.sh
# Walker UI Plugin for Matrix Capture (Screenshot, OCR, & Screenrecord)

# DESC: Provides a user interface for screen and window capturing.

# Fail fast, fail loud
set -Eeuo pipefail
trap 'echo -e "\e[31m[!] Error: Script failed on line \$LINENO\e[0m" >&2' ERR

# Standard logging functions
info()    { echo -e "\e[34m[*]\e[0m \$1"; }
warn()    { echo -e "\e[33m[!]\e[0m \$1"; }
die()     { echo -e "\e[31m[✘]\e[0m \$1" >&2; exit 1; }
success() { echo -e "\e[32m[✔]\e[0m \$1"; }

# Help Menu
show_help() {
    cat << EOF
Usage: \$(basename "\$0") [OPTIONS]

Provides a user interface for screen and window capturing.

Options:
  -h, --help    Show this help message and exit
EOF
}

if [[ "\${1:-}" == "-h" || "\${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi


SCREENSHOT_DIR="${XDG_PICTURES_DIR:-$HOME/Pictures/Screenshots}"
VIDEO_DIR="${XDG_VIDEOS_DIR:-$HOME/Videos/Screenrecords}"
mkdir -p "$SCREENSHOT_DIR" "$VIDEO_DIR"

# Read active theme dynamically, fallback to matrix-minimal
read -r WALKER_THEME < "$HOME/.config/matrix/settings/walker-theme" 2>/dev/null || WALKER_THEME="matrix-minimal"
if [ -z "$WALKER_THEME" ]; then
    WALKER_THEME="matrix-minimal"
fi

# ── Coordinate Generators for Smart Snapping ───────────────────
JQ_MONITOR_GEO='
  def format_geo:
    .x as $x | .y as $y |
    (.width / .scale | floor) as $w |
    (.height / .scale | floor) as $h |
    .transform as $t |
    if $t == 1 or $t == 3 then
      "\($x),\($y) \($h)x\($w)"
    else
      "\($x),\($y) \($w)x\($h)"
    end;
'
active_workspace() {
  hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .activeWorkspace.id'
}
window_rects() {
  hyprctl clients -j | jq -r --arg ws "$(active_workspace)" \
    '[.[] | select(.workspace.id == ($ws | tonumber) and .hidden != true) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"] | unique[]'
}
monitor_rects() {
  hyprctl monitors -j | jq -r --arg ws "$(active_workspace)" "${JQ_MONITOR_GEO} .[] | select(.activeWorkspace.id == (\$ws | tonumber)) | format_geo"
}
get_rectangles() {
  monitor_rects
  window_rects
}


# ── Check Active Recording ─────────────────────────────────────
# If triggered with 'stop' (e.g. from Waybar click), kill directly without UI
if [[ "${1:-}" == "stop" || "${1:-}" == "--stop" ]]; then
    if pgrep -f "^gpu-screen-recorder" >/dev/null; then
        notify-send -a "Matrix Capture" "Stopping..." "Finalizing video file..." -t 2000
        pkill -SIGINT -f "^gpu-screen-recorder"
        pkill -f "MatrixWebcamOverlay" 2>/dev/null
        
        # Wait for gpu-screen-recorder to finish writing the MP4 header
        while pgrep -f "^gpu-screen-recorder" >/dev/null; do sleep 0.1; done
        
        pkill -RTMIN+8 waybar
        sleep 1
        LATEST_MP4=$(ls -t "$VIDEO_DIR"/*.mp4 2>/dev/null | head -n 1)
        NACTION=$(notify-send -a "Matrix Capture" "Screen recording saved!" "Saved to $VIDEO_DIR" -A "play=Open in MPV" -t 5000)
        if [[ "$NACTION" == "play" && -n "$LATEST_MP4" ]]; then
            mpv "$LATEST_MP4" &
        fi
    fi
    exit 0
fi

# If gpu-screen-recorder is running, bypass the main menu and show the STOP option
if pgrep -f "^gpu-screen-recorder" >/dev/null; then
    ACTION=$(echo -e "  Stop Recording & Save" | walker --dmenu --placeholder "Recording is active..." --theme "$WALKER_THEME" 2>/dev/null)
    [[ -z "$ACTION" ]] && exit 0
    
    notify-send -a "Matrix Capture" "Stopping..." "Finalizing video file..." -t 2000
    
    # SIGINT is required by gpu-screen-recorder to save the MP4 properly without corruption
    pkill -SIGINT -f "^gpu-screen-recorder"
    pkill -f "MatrixWebcamOverlay" 2>/dev/null
    
    # Wait for gpu-screen-recorder to finish writing the MP4 header
    while pgrep -f "^gpu-screen-recorder" >/dev/null; do sleep 0.1; done
    
    # Trigger Waybar to hide the recording indicator instantly
    pkill -RTMIN+8 waybar
    
    sleep 1
    LATEST_MP4=$(ls -t "$VIDEO_DIR"/*.mp4 2>/dev/null | head -n 1)
    NACTION=$(notify-send -a "Matrix Capture" "Screen recording saved!" "Saved to $VIDEO_DIR" -A "play=Open in MPV" -t 5000)
    if [[ "$NACTION" == "play" && -n "$LATEST_MP4" ]]; then
        mpv "$LATEST_MP4" &
    fi
    exit 0
fi

# ── State 1: Choose Action ─────────────────────────────────────
MENU_1="󰄄  Screenshot (Save & Edit)\n󰴑  Text Capture (OCR)\n  Screen Record"
ACTION=$(echo -e "$MENU_1" | walker --dmenu --placeholder "Select Capture Mode..." --theme "$WALKER_THEME" 2>/dev/null)

[[ -z "$ACTION" ]] && exit 0

# ── State 2: Audio/Webcam Options (If Screen Record) ───────────
AUDIO_ARGS=()
WEBCAM_ENABLED=false
if [[ "$ACTION" == *"Screen Record"* ]]; then
    MENU_AUDIO="1. Mute (Video Only)\n2. Desktop Audio\n3. Desktop + Mic\n4. Desktop + Mic + Webcam"
    AUDIO_OPT=$(echo -e "$MENU_AUDIO" | walker --dmenu --placeholder "Select Audio/Webcam Setup..." --theme "$WALKER_THEME" 2>/dev/null)
    
    [[ -z "$AUDIO_OPT" ]] && exit 0
    
    if [[ "$AUDIO_OPT" == *"Desktop Audio"* ]]; then
        AUDIO_ARGS=(-a default_output -ac aac)
    elif [[ "$AUDIO_OPT" == *"Desktop + Mic"* ]]; then
        AUDIO_ARGS=(-a "default_output|default_input" -ac aac)
    elif [[ "$AUDIO_OPT" == *"Webcam"* ]]; then
        AUDIO_ARGS=(-a "default_output|default_input" -ac aac)
        WEBCAM_ENABLED=true
    fi
fi

# ── State 3: Region Selection ──────────────────────────────────
MENU_2="󰒉  Selection (Draw Region)\n󰍹  Full Screen"
REGION=$(echo -e "$MENU_2" | walker --dmenu --placeholder "Select Target Region..." --theme "$WALKER_THEME" 2>/dev/null)

[[ -z "$REGION" ]] && exit 0

# Wait for Walker to disappear so it isn't captured
sleep 0.3

# Process Selection Geometry
SELECTION=""
GSR_SELECTION=""

if [[ "$REGION" == *"Selection"* ]]; then
    # We only freeze the screen for Screenshots and OCR, not for video recording!
    if [[ "$ACTION" != *"Screen Record"* ]]; then
        hyprpicker -r -z >/dev/null 2>&1 &
        FREEZE_PID=$!
        sleep 0.1
    fi
    
    if [[ "$ACTION" == *"Screen Record"* ]]; then
        # gpu-screen-recorder requires WxH+X+Y format
        GSR_SELECTION=$(get_rectangles | slurp -f "%wx%h+%x+%y" 2>/dev/null)
        [[ -z "$GSR_SELECTION" ]] && exit 0
    else
        # grim uses standard slurp output (X,Y WxH)
        SELECTION=$(get_rectangles | slurp 2>/dev/null)
        [[ -n $FREEZE_PID ]] && kill $FREEZE_PID 2>/dev/null
        [[ -z "$SELECTION" ]] && exit 0
    fi
fi

# ── State 4: Execution ─────────────────────────────────────────
if [[ "$ACTION" == *"Screenshot"* ]]; then
    FILEPATH="$SCREENSHOT_DIR/screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png"
    
    if [[ -n "$SELECTION" ]]; then
        grim -g "$SELECTION" "$FILEPATH"
    else
        MONITOR=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name')
        grim -o "$MONITOR" "$FILEPATH"
    fi
    
    if [ $? -eq 0 ]; then
        wl-copy --type image/png < "$FILEPATH"
        NACTION=$(notify-send -a "Matrix Capture" -i "$FILEPATH" "Screenshot Saved" "Saved to disk and clipboard." -A "edit=Edit in Tensaku" -t 5000)
        
        # Only launch Tensaku if the user clicked the Edit action
        if [[ "$NACTION" == "edit" ]]; then
            if command -v tensaku-edit &>/dev/null; then
                tensaku-edit "$FILEPATH" &
            elif command -v tensaku &>/dev/null; then
                tensaku "$FILEPATH" &
            fi
        fi
    else
        notify-send -a "Matrix Capture" -u critical "Screenshot Failed" "Could not save screenshot."
    fi

elif [[ "$ACTION" == *"Text Capture"* ]]; then
    notify-send -a "Matrix Capture" "Scanning Text..." "Running OCR on target." -t 1500
    
    if [[ -n "$SELECTION" ]]; then
        TEXT=$(grim -g "$SELECTION" - | tesseract stdin stdout --oem 1 --psm 6 -l eng+urd --dpi 300 -c preserve_interword_spaces=1 2>/dev/null)
    else
        MONITOR=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name')
        TEXT=$(grim -o "$MONITOR" - | tesseract stdin stdout --oem 1 --psm 6 -l eng+urd --dpi 300 -c preserve_interword_spaces=1 2>/dev/null)
    fi
    
    if [[ -n "$TEXT" ]]; then
        printf "%s" "$TEXT" | wl-copy
        notify-send -a "Matrix Capture" "OCR Complete" "Text successfully copied to clipboard!"
    else
        notify-send -a "Matrix Capture" -u critical "OCR Failed" "No text detected."
    fi

elif [[ "$ACTION" == *"Screen Record"* ]]; then
    # Start Webcam Overlay if enabled
    if [[ "$WEBCAM_ENABLED" == "true" ]]; then
        # Dynamically find the first connected video device
        WEBCAM_DEVICE=$(v4l2-ctl --list-devices 2>/dev/null | grep "/dev/video" | head -n 1 | awk '{print $1}')
        if [[ -n "$WEBCAM_DEVICE" ]]; then
            mpv "av://v4l2:$WEBCAM_DEVICE" \
                --profile=low-latency --untimed --no-cache \
                --title="MatrixWebcamOverlay" \
                --no-border --no-audio --no-osc --osd-level=0 \
                --really-quiet &>/dev/null &
            sleep 0.5 # Give MPV time to map the window
        fi
    fi

    FILENAME="$VIDEO_DIR/screenrecording-$(date +'%Y-%m-%d_%H-%M-%S').mp4"
    
    if [[ -n "$GSR_SELECTION" ]]; then
        gpu-screen-recorder -w "$GSR_SELECTION" -k auto -f 60 -o "$FILENAME" "${AUDIO_ARGS[@]}" &
    else
        # Fullscreen recording: Find the name of the currently focused monitor for Wayland
        MONITOR=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name')
        gpu-screen-recorder -w "$MONITOR" -k auto -f 60 -o "$FILENAME" "${AUDIO_ARGS[@]}" &
    fi
    
    # Trigger Waybar to show the recording indicator instantly
    pkill -RTMIN+8 waybar
    
    notify-send -a "Matrix Capture" "Recording Started" "Trigger this script again to stop recording." -t 3000
fi
