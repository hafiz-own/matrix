-- -----------------------------------------------------
-- Display mode (F8 / SUPER + P)
-- Dell's F8 "switch display" key sends SUPER + P, like Windows' Win+P.
-- Each press cycles: Extend -> Mirror -> External only -> Laptop only.
-- Extend re-applies monitors.lua (the nwg-displays layout).
-- -----------------------------------------------------
local LAPTOP = "eDP-1"
local MONITORS = os.getenv("HOME") .. "/.config/hypr/monitors.lua"

local MODES = { "Extend", "Mirror", "External only", "Laptop only" }
local current = 1
local external = nil -- remembered so "Laptop only" can bring it back

local function find_external()
    for _, m in ipairs(hl.get_monitors()) do
        if m.name ~= LAPTOP then
            return m.name
        end
    end
    return external
end

local function notify(title, body)
    hl.dispatch(hl.dsp.exec_cmd(
        "notify-send --urgency=low --expire-time=1500 --icon=video-display-symbolic"
        .. " --hint=string:synchronous:display-mode --transient"
        .. " '" .. title .. "' '" .. body .. "'"
    ))
end

local function extend()
    local ok = pcall(dofile, MONITORS)
    if not ok then
        hl.monitor({ output = LAPTOP, mode = "preferred", position = "auto", scale = 1 })
        hl.monitor({ output = external, mode = "preferred", position = "auto", scale = 1 })
    end
end

local apply = {
    ["Extend"] = extend,
    ["Mirror"] = function ()
        hl.monitor({ output = LAPTOP, mode = "preferred", position = "auto", scale = 1 })
        hl.monitor({ output = external, mode = "preferred", position = "auto", scale = 1, mirror = LAPTOP })
    end,
    ["External only"] = function ()
        hl.monitor({ output = external, mode = "preferred", position = "auto", scale = 1 })
        hl.monitor({ output = LAPTOP, disabled = true })
    end,
    ["Laptop only"] = function ()
        hl.monitor({ output = LAPTOP, mode = "preferred", position = "auto", scale = 1 })
        hl.monitor({ output = external, disabled = true })
    end,
}

local function cycle()
    external = find_external()
    if not external then
        notify("Display", "No external display connected")
        return
    end
    -- Leave mirror/disabled state cleanly before applying the next mode
    extend()
    current = current % #MODES + 1
    apply[MODES[current]]()
    notify("Display: " .. MODES[current], external)
end

hl.bind("SUPER + P", cycle, { description = "Cycle display mode (Extend/Mirror/External/Laptop)" })
hl.bind("XF86Display", cycle, { description = "Cycle display mode (Extend/Mirror/External/Laptop)" })
