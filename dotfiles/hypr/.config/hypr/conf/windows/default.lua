hl.config({
    general = {
        gaps_in  = 1,
        gaps_out = 1,
        border_size = 2,
        col = {
            active_border   = { colors = {"#FF0040", "#B600FF"}, angle = 0 },
            inactive_border = on_primary,
        },
        resize_on_border = true,
        allow_tearing = false,
        layout = "dwindle",
    }
})
