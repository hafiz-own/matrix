-- -----------------------------------------------------
-- Display mode (Fn+F8 sends SUPER + P, like Windows' Win+P)
-- Opens a walker menu: Extend, Mirror, External only, Laptop only.
-- SUPER + SHIFT + P (keybindings) reloads Hyprland = back to monitors.lua.
-- -----------------------------------------------------
local display = require("conf.display")
local LAPTOP = display.LAPTOP
local PICKER = os.getenv("HOME") .. "/.config/hypr/scripts/display-mode.sh"

local function notify(body)
    hl.dispatch(hl.dsp.exec_cmd(
        "notify-send --urgency=low --expire-time=2000 --icon=video-display-symbolic"
        .. " --hint=string:synchronous:display-mode --transient 'Display' '" .. body .. "'"
    ))
end

local apply = {
    ["Extend"] = function (ext) display.extend(ext) end,
    ["Mirror"] = function (ext)
        display.enable(LAPTOP)
        display.enable(ext, { mirror = LAPTOP })
    end,
    ["External only"] = function (ext) display.laptop_off(ext) end,
    ["Laptop only"] = function (ext)
        display.enable(LAPTOP)
        hl.monitor({ output = ext, disabled = true })
    end,
}

-- Called by the picker through hyprctl eval
function display.set_mode(name, ext)
    if not ext then
        notify("No external display connected")
        return
    end
    -- Laptop only with the lid shut would leave no visible output
    if name == "Laptop only" and display.lid_closed() then
        notify("Lid is closed, staying on " .. display.mode)
        return
    end
    apply[name](ext)
    display.mode = name
    notify(name)
end

hl.bind("SUPER + P", function ()
    if not display.external() then
        notify("No external display connected")
        return
    end
    hl.dispatch(hl.dsp.exec_cmd(PICKER .. " '" .. display.mode .. "'"))
end, { description = "Pick display mode (Extend/Mirror/External/Laptop)" })
