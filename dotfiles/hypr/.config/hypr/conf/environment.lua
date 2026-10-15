-- Theme names come from the GTK settings (written by nwg-look) so there is
-- one source of truth. Read once at compositor start; a theme switch
-- applies on next login.
--  * QS_ICON_THEME: Quickshell resolves app icons through Qt's icon theme,
--    which does not follow the GTK setting on its own.
--  * XCURSOR_*/HYPRCURSOR_*: Hyprland's cursor and the cursor of apps it
--    starts (replaces `hyprctl setcursor` in autostart).
local gtk = {
    ["gtk-icon-theme-name"]   = nil,
    ["gtk-cursor-theme-name"] = "Bibata-Modern-Classic",
    ["gtk-cursor-theme-size"] = "24",
}
local settings = io.open(os.getenv("HOME") .. "/.config/gtk-3.0/settings.ini", "r")
if settings then
    for line in settings:lines() do
        local key, value = line:match("^%s*([%w%-]+)%s*=%s*(.-)%s*$")
        if key and value ~= "" and (gtk[key] ~= nil or key == "gtk-icon-theme-name") then
            gtk[key] = value
        end
    end
    settings:close()
end
if gtk["gtk-icon-theme-name"] then
    hl.env("QS_ICON_THEME", gtk["gtk-icon-theme-name"])
end
hl.env("XCURSOR_THEME", gtk["gtk-cursor-theme-name"])
hl.env("XCURSOR_SIZE", gtk["gtk-cursor-theme-size"])
hl.env("HYPRCURSOR_THEME", gtk["gtk-cursor-theme-name"])
hl.env("HYPRCURSOR_SIZE", gtk["gtk-cursor-theme-size"])

local name = "default.lua"
load_variant(name,"environments")
