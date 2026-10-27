-- -----------------------------------------------------
-- Display mode (Fn+F8 sends SUPER + P, like Windows' Win+P)
-- Each press cycles: Extend -> Mirror -> External only -> Laptop only.
-- SUPER + SHIFT + P (keybindings) reloads Hyprland = back to monitors.lua.
-- -----------------------------------------------------
local display = require("conf.display")
local LAPTOP = display.LAPTOP

-- Testing: fall back to Extend after this many ms unless the mode is
-- confirmed with another press. Set to nil once every mode is verified.
local REVERT_MS = 15000

local MODES = { "Extend", "Mirror", "External only", "Laptop only" }
local generation = 0 -- cancels stale revert timers

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

local function set_mode(name, ext)
    apply[name](ext)
    display.mode = name
    generation = generation + 1
    if REVERT_MS and name ~= "Extend" then
        local gen = generation
        notify(name .. " (reverts in " .. REVERT_MS // 1000 .. " s)")
        hl.timer(function ()
            if gen == generation then
                display.extend(display.external())
                generation = generation + 1
                notify("Extend (reverted)")
            end
        end, { timeout = REVERT_MS, type = "oneshot" })
    else
        notify(name)
    end
end

display.set_mode = set_mode -- for hyprctl eval

local function cycle()
    local ext = display.external()
    if not ext then
        notify("No external display connected")
        return
    end
    local i = 1
    for k, name in ipairs(MODES) do
        if name == display.mode then i = k end
    end
    local next = MODES[i % #MODES + 1]
    -- Laptop only with the lid shut would leave no visible output
    if next == "Laptop only" and display.lid_closed() then
        next = "Extend"
    end
    set_mode(next, ext)
end

hl.bind("SUPER + P", cycle, { description = "Cycle display mode (Extend/Mirror/External/Laptop)" })
