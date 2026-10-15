hl.window_rule({
    name = "matrix-webcam-overlay",
    match = { class = "MatrixWebcamOverlay" },
    float = true,
    pin = true,
    no_initial_focus = true,
    size = "(monitor_h*1/5) (monitor_h*1/5)",
    move = "(monitor_w-monitor_h*1/5-40) (monitor_h-monitor_h*1/5-40)",
    rounding = 20
})

hl.window_rule({
    name = "matrix-screensaver",
    float = true,
    size = "100% 100%",
    match = { class = "matrix-screensaver" },
    fullscreen = true
})

hl.window_rule({
    name = "dotfiles-floating",
    match = { class = "dotfiles-floating" },
    float = true,
    size = "50% 60%",
    center = true,
    rounding = 15
})

hl.window_rule({
    name = "magic-scratchpad-default-layout",
	match = { workspace = "special:magic", class = "kitty" },
    float = true,
    size = "50% 60%",
    center = true,
})
hl.window_rule({
    match = {
        class = ".*obs.*",
        title = "^Windowed Projector.*"
    },
    workspace = "7 silent",
    fullscreen = true
})

-- Keep the screen awake while anything is fullscreen (videos, games,
-- presentations), even if the app itself doesn't send an idle inhibitor.
hl.window_rule({
    name = "idle-inhibit-fullscreen",
    match = { class = ".*" },
    idle_inhibit = "fullscreen",
})

-- Small utility windows float, centered
hl.window_rule({
    name = "float-utilities",
    match = { class = "^(org\\.pulseaudio\\.pavucontrol|pavucontrol|\\.?blueman-manager(-wrapped)?|nm-connection-editor|xdg-desktop-portal-gtk|polkit-gnome-authentication-agent-1)$" },
    float = true,
    center = true,
})

-- Picture-in-Picture (Firefox: "Picture-in-Picture", Chromium/Brave:
-- "Picture in picture"): float, pinned, bottom-right, aspect kept
hl.window_rule({
    name = "pip",
    match = { title = "^(Picture-in-Picture|Picture in picture)$" },
    float = true,
    pin = true,
    keep_aspect_ratio = true,
    size = "(monitor_w*0.25) (monitor_w*0.25*9/16)",
    move = "(monitor_w-monitor_w*0.25-20) (monitor_h-monitor_w*0.25*9/16-20)",
})
