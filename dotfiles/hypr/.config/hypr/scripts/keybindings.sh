#!/usr/bin/env bash
# DESC: Keybinding cheat sheet (SUPER+F1, waybar Apps right-click).
#       Lists every bind that has a description in walker's dmenu as
#       "action — keys" (searchable by either). The 20 workspace binds
#       are collapsed into two lines.

hyprctl binds -j | jq -r '
    def mods:
        [ (if . % 128 >= 64 then "SUPER" else empty end),
          (if . % 8   >= 4  then "CTRL"  else empty end),
          (if . % 16  >= 8  then "ALT"   else empty end),
          (if . % 2   >= 1  then "SHIFT" else empty end) ];
    def keyname:
        { "mouse:272": "LMB drag", "mouse:273": "RMB drag",
          "mouse_down": "scroll down", "mouse_up": "scroll up" }[.] // .;
    ( "Focus workspace 1–10 — SUPER + 1…0",
      "Move window to workspace 1–10 — SUPER + SHIFT + 1…0" ),
    ( .[]
      | select(.has_description and (.key | startswith("switch:") | not))
      | select(.description | test("^(Focus|Move window to) workspace [0-9]+$") | not)
      | "\(.description) — \((.modmask | mods) + [.key | keyname] | join(" + "))" )
' | "$HOME/.config/walker/launch.sh" -d -N -H -p "Keybindings" >/dev/null
