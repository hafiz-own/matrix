local utils = require 'mp.utils'

-- =========================================================================
-- 1. Hold SPACE to Speed Up to 2.0x, Tap to Toggle Pause
-- =========================================================================
local timer = nil
local original_speed = 1.0
local is_speeding = false

local function handle_space(table)
    if table.event == "down" then
        if timer then timer:kill() end
        timer = mp.add_timeout(0.3, function()
            original_speed = mp.get_property_native("speed")
            mp.set_property("speed", 2.0)
            is_speeding = true
            mp.osd_message("Speed: 2.0x (Hold)", 2)
        end)
    elseif table.event == "up" then
        if timer then 
            timer:kill() 
            timer = nil
        end
        if is_speeding then
            mp.set_property("speed", original_speed)
            is_speeding = false
            mp.osd_message("Speed: " .. string.format("%.2f", original_speed) .. "x", 2)
        else
            local pause = mp.get_property_native("pause")
            mp.set_property("pause", not pause)
        end
    end
end

mp.add_key_binding("SPACE", "space_speed_pause", handle_space, {complex=true})

-- =========================================================================
-- 2. Press Y to show Playlist Time Remaining (Top Right)
-- =========================================================================
local function format_time(seconds)
    if not seconds then return "00:00:00" end
    local s = seconds
    local h = math.floor(s / 3600)
    s = s % 3600
    local m = math.floor(s / 60)
    s = math.floor(s % 60)
    return string.format("%02d:%02d:%02d", h, m, s)
end

local function get_duration(filename)
    if not filename then return 0 end
    if filename:match("^http") or filename:match("^ytdl://") or filename:match("^magnet:") then
        return 0
    end
    
    local cmd = {
        "ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", filename
    }
    local res = utils.subprocess({ args = cmd, cancellable = false })
    if res.status == 0 and res.stdout then
        local dur = tonumber(res.stdout)
        if dur then return dur end
    end
    return 0
end

local playlist_ov = nil
local playlist_ov_timer = nil

local function show_playlist_remaining()
    local playlist = mp.get_property_native("playlist")
    local current_pos = mp.get_property_native("playlist-pos-1") -- 1-indexed

    if not playlist or not current_pos then
        mp.osd_message("No playlist active.", 4)
        return
    end

    local total_time_left = 0
    local has_unknown = false

    -- Add current video remaining
    local duration = mp.get_property_native("duration")
    local time_pos = mp.get_property_native("time-pos")
    if duration and time_pos then
        total_time_left = total_time_left + (duration - time_pos)
    else
        has_unknown = true
    end

    -- Add remaining videos in playlist
    for i = current_pos + 1, #playlist do
        local item = playlist[i]
        local dur = item.playtime
        if not dur then
            dur = get_duration(item.filename)
        end
        
        if dur and dur > 0 then
            total_time_left = total_time_left + dur
        else
            has_unknown = true
        end
    end

    local current_speed = mp.get_property_native("speed")
    
    local msg = "Playlist Left: " .. format_time(total_time_left) .. " (1x)"
    if current_speed ~= 1.0 then
        local speed_time_left = total_time_left / current_speed
        msg = msg .. "\nAt " .. string.format("%.2f", current_speed) .. "x: " .. format_time(speed_time_left)
    end
    
    if has_unknown then
        msg = msg .. "\n(Some items unknown/skipped)"
    end

    if playlist_ov then
        playlist_ov:remove()
        if playlist_ov_timer then playlist_ov_timer:kill() end
    end

    playlist_ov = mp.create_osd_overlay("ass-events")
    playlist_ov.data = "{\\an9}" .. msg
    playlist_ov:update()

    playlist_ov_timer = mp.add_timeout(5, function()
        if playlist_ov then
            playlist_ov:remove()
            playlist_ov = nil
        end
    end)
end

mp.add_key_binding("y", "playlist_remaining", show_playlist_remaining)
