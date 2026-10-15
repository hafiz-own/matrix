--    __  _____  _____      __  ____  ____
--   /  |/  / / / / / | /| / / / __ \/ __/
--  / /|_/ / /_/_  _/ |/ |/ / / /_/ /\ \  
-- /_/  /_/____//_/ |__/|__/  \____/___/
--   
-- Advanced configuration for Hyprland

-- FUNCTIONS
require("functions")

-- MONITORS
require("monitors")
require("conf.monitor")
require("conf.lid")

-- INPUT
require("input")


-- GESTURE
require("gestures")

-- AUTOSTART
require("conf.autostart")


-- CONFIGURATION
require("conf.keybinding")
require("conf.environment")
require("conf.window")
require("conf.decoration")
require("conf.layout")
require("workspaces")
require("conf.workspace")
require("conf.misc")
require("conf.windowrule")
require("conf.animation")

-- CUSTOM
local f = io.open(os.getenv("HOME") .. "/.config/hypr/custom.lua", "r")
if f then
    f:close()
    require("custom")
end

-- HYPRMOD
require("hyprland-gui")

