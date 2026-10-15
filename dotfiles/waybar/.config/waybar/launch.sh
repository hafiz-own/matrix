#!/usr/bin/env bash
#                    __
#  _    _____ ___ __/ /  ___ _____
# | |/|/ / _ `/ // / _ \/ _ `/ __/
# |__,__/\_,_/\_, /_.__/\_,_/_/
#            /___/
#

# -----------------------------------------------------
# Prevent duplicate launches: only the first parallel
# invocation proceeds; all others exit immediately.
# -----------------------------------------------------
lock_file="$XDG_RUNTIME_DIR/waybar-launch.lock"
exec 200>"$lock_file"
flock -n 200 || exit 0

# -----------------------------------------------------
# Quit all running waybar instances (wait until gone)
# -----------------------------------------------------
pkill -x waybar
for _ in {1..60}; do pgrep -x waybar >/dev/null || break; sleep 0.05; done
pkill -9 -x waybar 2>/dev/null   # still alive after 3s: force it

# -----------------------------------------------------
# Default theme: /THEMEFOLDER;/VARIATION
# -----------------------------------------------------
default_theme="/matrix-minimal;/matrix-minimal"
theme_file="$HOME/.config/matrix/settings/waybar-theme.sh"

# -----------------------------------------------------
# Get current theme information from ~/.config/matrix/settings/waybar-theme.sh
# -----------------------------------------------------
if [ -f "$theme_file" ]; then
    themestyle=$(<"$theme_file")
else
    echo "$default_theme" >"$theme_file"
    themestyle=$default_theme
fi
IFS=';' read -ra arrThemes <<<"$themestyle"
if [ ! -f "$HOME/.config/waybar/themes${arrThemes[1]}/style.css" ]; then
    themestyle=$default_theme
    IFS=';' read -ra arrThemes <<<"$themestyle"
fi
echo ":: Theme: ${arrThemes[0]}"

# -----------------------------------------------------
# Loading the configuration
# -----------------------------------------------------
config_file="config"
style_file="style.css"

# Standard files can be overwritten with an existing config-custom or style-custom.css
if [ -f "$HOME/.config/waybar/themes${arrThemes[0]}/config-custom" ]; then
    config_file="config-custom"
fi
if [ -f "$HOME/.config/waybar/themes${arrThemes[1]}/style-custom.css" ]; then
    style_file="style-custom.css"
fi

# Check if waybar-disabled file exists
if [ ! -f "$HOME/.config/matrix/settings/waybar-disabled" ]; then
    # Use the HYPRLAND_INSTANCE_SIGNATURE already set by Hyprland in the session
    # (avoids calling `hyprctl instances` which is broken when hyprctl is a QuickShell wrapper)
    waybar -c "$HOME/.config/waybar/themes${arrThemes[0]}/$config_file" -s "$HOME/.config/waybar/themes${arrThemes[1]}/$style_file" &
else
    echo ":: Waybar disabled"
fi

# Explicitly release the lock (optional) -> flock releases on exit
flock -u 200
exec 200>&-
