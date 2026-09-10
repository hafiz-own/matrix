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
