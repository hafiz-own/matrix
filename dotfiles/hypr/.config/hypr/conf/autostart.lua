hl.on("hyprland.start", function ()
    -- Export the session environment to systemd/dbus, restart the portals so
    -- they pick it up, then start hyprland-session.target, which brings up
    -- the session daemons as user units (hypridle, swaync, waybar, elephant,
    -- walker, voxtype, low-battery). One shell so the steps run in order (exec_cmd is async).
    local env = table.concat({
        "WAYLAND_DISPLAY", "DISPLAY", "XDG_CURRENT_DESKTOP", "XDG_SESSION_TYPE",
        "HYPRLAND_INSTANCE_SIGNATURE", "QT_QPA_PLATFORMTHEME", "QS_ICON_THEME",
        "XCURSOR_THEME", "XCURSOR_SIZE", "HYPRCURSOR_THEME", "HYPRCURSOR_SIZE",
        "VK_DRIVER_FILES",
    }, " ")
    hl.exec_cmd("sh -c 'dbus-update-activation-environment --systemd " .. env .. "; "
        .. "systemctl --user stop xdg-desktop-portal xdg-desktop-portal-hyprland; "
        .. "systemctl --user start xdg-desktop-portal-hyprland xdg-desktop-portal; "
        .. "systemctl --user start --no-block hyprland-session.target'")

    -- Start polkit daemon
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")

    -- Load GTK settings
    hl.exec_cmd("~/.config/hypr/scripts/gtk.sh")

    -- Start a terminal instance
    hl.exec_cmd("kitty")

    -- Start hyprpaper
    -- hl.exec_cmd("hyprpaper")

    -- Load cliphist history
    hl.exec_cmd("wl-paste --watch cliphist store")

    -- Start autostart cleanup
    hl.exec_cmd("~/.config/hypr/scripts/cleanup.sh")
end)

-- Stop the session units with the compositor (they would otherwise keep
-- restarting against a dead Wayland socket).
hl.on("hyprland.shutdown", function ()
    hl.exec_cmd("systemctl --user stop --no-block hyprland-session.target")
end)
