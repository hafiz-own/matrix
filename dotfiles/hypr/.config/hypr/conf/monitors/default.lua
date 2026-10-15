-------------------------------------------------------
-- Monitor Setup
-- name: "Default"
-- Use nwg-displays to set your monitors
-------------------------------------------------------

-- Catch-all for displays without their own rule (projectors, other
-- screens). Named outputs in ~/.config/hypr/monitors.lua take precedence.
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1
})
