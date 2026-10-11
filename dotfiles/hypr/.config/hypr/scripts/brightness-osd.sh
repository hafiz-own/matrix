#!/usr/bin/env bash
# brightness-osd.sh — change brightness and show an OSD notification
# Usage: brightness-osd.sh <brightnessctl-set-arg>
#   e.g. brightness-osd.sh 10%+
#        brightness-osd.sh 5%-

set -euo pipefail

STEP="${1:-10%+}"

# Apply the change
brightnessctl set "$STEP" --quiet

# Read back the new percentage (strips the trailing %)
PCT=$(brightnessctl info | grep -oP '\(\K[0-9]+(?=%\))')

# Choose icon based on level
if   (( PCT == 0 ));    then ICON="display-brightness-off-symbolic"
elif (( PCT <= 33 ));   then ICON="display-brightness-low-symbolic"
elif (( PCT <= 66 ));   then ICON="display-brightness-medium-symbolic"
else                         ICON="display-brightness-high-symbolic"
fi

# Send / replace a single "brightness" notification with a progress bar.
# -h int:value:PCT   → tells dunst/swaync to render a progress bar
# -h string:synchronous:brightness  → dunst stacks by tag (replaces previous)
# -e (transient) → swaync won't store it in the notification centre
notify-send \
    --urgency=low \
    --expire-time=1500 \
    --icon="$ICON" \
    --hint="int:value:${PCT}" \
    --hint="string:synchronous:brightness" \
    --transient \
    "Brightness" "${PCT}%"
