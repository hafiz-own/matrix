#!/usr/bin/env bash
# Resolve the selected waybar theme and exec waybar with it.
# Used as ExecStart of waybar.service (see systemd/.../waybar.service.d)
# and as a fallback by launch.sh when the service is not available.

default_theme="/matrix-minimal;/matrix-minimal"
theme_file="$HOME/.config/matrix/settings/waybar-theme.sh"
themes="$HOME/.config/waybar/themes"

themestyle=$default_theme
[ -f "$theme_file" ] && themestyle=$(<"$theme_file")
IFS=';' read -ra arrThemes <<<"$themestyle"
if [ ! -f "$themes${arrThemes[1]}/style.css" ]; then
    IFS=';' read -ra arrThemes <<<"$default_theme"
fi

# config-custom / style-custom.css override the theme's standard files
config="$themes${arrThemes[0]}/config"
style="$themes${arrThemes[1]}/style.css"
[ -f "$themes${arrThemes[0]}/config-custom" ] && config="$themes${arrThemes[0]}/config-custom"
[ -f "$themes${arrThemes[1]}/style-custom.css" ] && style="$themes${arrThemes[1]}/style-custom.css"

exec waybar -c "$config" -s "$style"
