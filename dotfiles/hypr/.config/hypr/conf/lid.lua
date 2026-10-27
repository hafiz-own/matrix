-- -----------------------------------------------------
-- Lid switch
-- Closing the lid with an external monitor connected turns the laptop
-- panel off (logind's HandleLidSwitchDocked=ignore keeps the system awake),
-- un-mirroring first so Mirror mode does not crash Hyprland.
-- Without an external monitor nothing happens here and logind handles the
-- lid as usual (suspend). Opening the lid re-applies monitors.lua.
-- -----------------------------------------------------
local display = require("conf.display")

hl.bind("switch:on:Lid Switch", function ()
    local ext = display.external()
    if ext then
        display.laptop_off(ext)
        display.mode = "External only"
    end
end, { locked = true, description = "Lid closed: disable laptop panel if docked" })

hl.bind("switch:off:Lid Switch", function ()
    display.extend(display.external())
end, { locked = true, description = "Lid opened: re-enable laptop panel" })
