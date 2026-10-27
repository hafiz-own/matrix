-- -----------------------------------------------------
-- Display helpers shared by display-mode.lua and lid.lua
-- Hyprland 0.56.2 crashes when a mirror source is disabled, and
-- hl.get_monitors() omits disabled and mirrored outputs, so:
--  - connectors are read from /sys/class/drm
--  - every re-enabled output gets disabled = false and mirror = ""
--  - the laptop panel is only disabled after un-mirroring, one frame later
-- -----------------------------------------------------
local M = {}

M.LAPTOP = "eDP-1"
M.mode = "Extend" -- reload re-applies monitors.lua, which is Extend

local MONITORS = os.getenv("HOME") .. "/.config/hypr/monitors.lua"

local function read(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("l")
    f:close()
    return s
end

-- First connected non-laptop connector, e.g. "HDMI-A-1"
function M.external()
    local ls = io.popen("ls /sys/class/drm")
    if not ls then return nil end
    for entry in ls:lines() do
        local name = entry:match("^card%d+%-(.+)$")
        if name and name ~= M.LAPTOP and not name:match("^eDP")
            and read("/sys/class/drm/" .. entry .. "/status") == "connected" then
            ls:close()
            return name
        end
    end
    ls:close()
    return nil
end

function M.lid_closed()
    local s = read("/proc/acpi/button/lid/LID0/state")
    return s ~= nil and s:match("closed") ~= nil
end

-- Specs from monitors.lua (nwg-displays layout), keyed by output
local function layout()
    local specs = {}
    local chunk = loadfile(MONITORS, "t", {
        hl = { monitor = function (s) specs[s.output] = s end },
    })
    if chunk then pcall(chunk) end
    return specs
end

-- Enable an output with its saved spec; extra fields (e.g. mirror) override
function M.enable(output, extra)
    local spec = layout()[output] or { output = output, mode = "preferred", position = "auto", scale = 1 }
    local s = {}
    for k, v in pairs(spec) do s[k] = v end
    s.disabled = false
    s.mirror = "" -- nil keeps an old mirror; "" clears it
    for k, v in pairs(extra or {}) do s[k] = v end
    hl.monitor(s)
end

local function active(output)
    for _, m in ipairs(hl.get_monitors()) do
        if m.name == output then return true end
    end
    return false
end

-- Laptop panel off, external on. Never leaves zero outputs.
function M.laptop_off(ext)
    M.enable(ext) -- also un-mirrors it
    hl.timer(function ()
        if active(ext) then
            hl.monitor({ output = M.LAPTOP, disabled = true })
        end
    end, { timeout = 300, type = "oneshot" })
end

function M.extend(ext)
    M.enable(M.LAPTOP)
    if ext then M.enable(ext) end
    M.mode = "Extend"
end

return M
