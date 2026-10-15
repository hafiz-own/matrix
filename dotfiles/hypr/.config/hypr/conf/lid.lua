-- -----------------------------------------------------
-- Lid switch
-- Closing the lid with an external monitor connected turns the laptop
-- panel off (logind's HandleLidSwitchDocked=ignore keeps the system awake).
-- Without an external monitor nothing happens here and logind handles the
-- lid as usual (suspend). Opening the lid re-applies monitors.lua.
-- -----------------------------------------------------
local LAPTOP = "eDP-1"
local MONITORS = os.getenv("HOME") .. "/.config/hypr/monitors.lua"

local function external_connected()
    for _, m in ipairs(hl.get_monitors()) do
        if m.name ~= LAPTOP then
            return true
        end
    end
    return false
end

hl.bind("switch:on:Lid Switch", function ()
    if external_connected() then
        hl.monitor({ output = LAPTOP, disabled = true })
    end
end, { locked = true, description = "Lid closed: disable laptop panel if docked" })

hl.bind("switch:off:Lid Switch", function ()
    -- Re-run the nwg-displays layout so the panel gets its saved mode/position
    local ok = pcall(dofile, MONITORS)
    if not ok then
        hl.monitor({ output = LAPTOP, mode = "preferred", position = "auto", scale = 1 })
    end
end, { locked = true, description = "Lid opened: re-enable laptop panel" })
