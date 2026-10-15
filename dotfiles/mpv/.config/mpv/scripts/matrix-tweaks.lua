local utils = require 'mp.utils'

-- =========================================================================
-- 1. Hold SPACE → 2.0x speed; Tap SPACE → Toggle Pause
-- =========================================================================
--
-- How it works:
--   - On key-down, start a 300ms timer.
--   - If the key is released before the timer fires → it was a tap → toggle pause.
--   - If the timer fires before release → it's a hold → jump to 2x speed.
--   - On key-up after a hold → restore original speed.
-- =========================================================================

local hold_timer   = nil   -- pending timer before we decide tap vs hold
local is_holding   = false -- true while we are in 2x hold mode
local saved_speed  = nil   -- speed captured just before going to 2x

local HOLD_THRESHOLD_MS = 250  -- ms to wait before treating as a hold (snappy & natural)
local SPEED_2X         = 2.0

local function on_space(event)
    -- Handle canceled key event (e.g. window lost focus or another key was pressed)
    if event.canceled then
        if hold_timer then hold_timer:kill(); hold_timer = nil end
        if is_holding then
            is_holding = false
            local restore = saved_speed or 1.0
            mp.set_property_number("speed", restore)
            saved_speed = nil
            mp.osd_message(("▶ Speed: %.2fx"):format(restore), 2)
        end
        return
    end

    -- Fallback for environments that cannot track separate down/up events
    if event.event == "press" then
        local paused = mp.get_property_native("pause")
        mp.set_property("pause", not paused)
        return
    end

    -- Ignore key repeat ticks so they never reset the timer
    if event.event == "repeat" then return end

    if event.event == "down" then
        -- If already holding or timer is running, ignore duplicate down events
        if is_holding or hold_timer then return end

        hold_timer = mp.add_timeout(HOLD_THRESHOLD_MS / 1000, function()
            hold_timer  = nil
            is_holding  = true
            saved_speed = mp.get_property_native("speed")
            mp.set_property_number("speed", SPEED_2X)
            mp.osd_message(("▶▶ %.1fx (hold SPACE)"):format(SPEED_2X), 99)
        end)

    elseif event.event == "up" then
        if hold_timer then
            -- Timer hadn't fired yet → tap → toggle pause
            hold_timer:kill()
            hold_timer = nil
            local paused = mp.get_property_native("pause")
            mp.set_property("pause", not paused)
        elseif is_holding then
            -- Hold released → restore original speed
            is_holding = false
            local restore = saved_speed or 1.0
            mp.set_property_number("speed", restore)
            saved_speed = nil
            mp.osd_message(("▶ Speed: %.2fx"):format(restore), 2)
        end
    end
end

-- Use add_forced_key_binding so this wins in ALL mpv contexts
-- (including when the OSC/uosc is hovered, menus are open, etc.)
mp.add_forced_key_binding("SPACE", "space_speed_pause", on_space, {complex = true})


-- =========================================================================
-- 2. Press Y → Show Playlist Time Remaining (Top Right)
--    Press Y again while overlay is visible → dismiss immediately
-- =========================================================================
--
-- Shows (top-right, 7s timeout):
--   Video N of M
--   Remaining: HH:MM:SS  (at 1x)
--   At Xx:     HH:MM:SS  (at current speed, if not 1x)
--   Total playlist: HH:MM:SS  (at 1x)
-- =========================================================================

-- ── helpers ──────────────────────────────────────────────────────────────

local function hms(seconds)
    if not seconds or seconds < 0 then return "??:??:??" end
    local s = math.floor(seconds + 0.5)
    local h = math.floor(s / 3600)
    s = s % 3600
    local m = math.floor(s / 60)
    s = s % 60
    if h > 0 then
        return string.format("%d:%02d:%02d", h, m, s)
    else
        return string.format("%d:%02d", m, s)
    end
end

-- Get duration of a local file via ffprobe.
-- Returns number of seconds, or nil on failure.
local function probe_duration(filename)
    if not filename then return nil end
    -- Skip URLs / streams – ffprobe would hang or fail
    if filename:match("^https?://") or filename:match("^ytdl://")
       or filename:match("^magnet:") or filename:match("^rtmp")
       or filename:match("^rtsp") then
        return nil
    end

    local res = utils.subprocess({
        args = {
            "ffprobe", "-v", "quiet",
            "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1",
            filename
        },
        cancellable = false,
        max_size     = 256,
    })
    if res.status == 0 and res.stdout then
        return tonumber(res.stdout:match("[%d%.]+"))
    end
    return nil
end

-- ── overlay state ─────────────────────────────────────────────────────────

local ov       = nil   -- mp.OsdOverlay object
local ov_timer = nil   -- auto-hide timer

local function dismiss_overlay()
    if ov_timer then ov_timer:kill(); ov_timer = nil end
    if ov then ov:remove(); ov = nil end
end

-- ── main logic ────────────────────────────────────────────────────────────

local function show_playlist_info()
    -- Toggle off if already showing
    if ov then
        dismiss_overlay()
        return
    end

    local playlist    = mp.get_property_native("playlist")
    local current_pos = mp.get_property_native("playlist-pos")   -- 0-indexed
    local speed       = mp.get_property_native("speed") or 1.0
    local duration    = mp.get_property_native("duration")
    local time_pos    = mp.get_property_native("time-pos")

    -- Guard: need a playlist
    if not playlist or #playlist == 0 then
        mp.osd_message("No playlist active.", 3)
        return
    end

    if not current_pos then current_pos = 0 end
    local current_1idx = current_pos + 1   -- human-readable 1-indexed
    local total_items  = #playlist

    -- ── accumulate remaining time ─────────────────────────────────────────
    local remaining_secs = 0
    local total_secs     = 0
    local unknown_count  = 0

    -- Current video: time left in it
    if duration and time_pos then
        local cur_remaining = math.max(0, duration - time_pos)
        remaining_secs      = remaining_secs + cur_remaining
        total_secs          = total_secs     + duration
    else
        unknown_count = unknown_count + 1
    end

    -- Preceding items: full duration (for total only)
    for i = 1, current_pos do
        local item = playlist[i]
        local dur  = probe_duration(item.filename)
        if dur then
            total_secs = total_secs + dur
        else
            unknown_count = unknown_count + 1
        end
    end

    -- Subsequent items: full duration (remaining + total)
    for i = current_1idx + 1, total_items do
        local item = playlist[i]
        local dur  = probe_duration(item.filename)
        if dur then
            remaining_secs = remaining_secs + dur
            total_secs     = total_secs     + dur
        else
            unknown_count  = unknown_count  + 1
        end
    end

    -- ── build ASS overlay lines ───────────────────────────────────────────
    -- \an9 = top-right anchor, \N = hard newline in ASS
    local W  = "{\\an9\\bord1.5\\shad1\\c&HFFFFFF&\\3c&H000000&\\fs22\\b1}"
    local N  = "{\\an9\\bord1.5\\shad1\\c&HFFFFFF&\\3c&H000000&\\fs20}"
    local G  = "{\\an9\\bord1.5\\shad1\\c&H80FF80&\\3c&H000000&\\fs20}"
    local S  = "{\\an9\\bord1.5\\shad1\\c&HCCCCCC&\\3c&H000000&\\fs18}"
    local GS = "{\\an9\\bord1.5\\shad1\\c&H80CC80&\\3c&H000000&\\fs18}"
    local HI = "{\\an9\\bord1\\shad0\\c&H8888FF&\\3c&H000000&\\fs16}"

    local parts = {}

    parts[#parts+1] = W .. string.format("Video %d of %d", current_1idx, total_items)
    parts[#parts+1] = N .. string.format("Remaining (1x):   %s", hms(remaining_secs))

    if math.abs(speed - 1.0) > 0.01 then
        parts[#parts+1] = G .. string.format("Remaining (%.2fx): %s", speed, hms(remaining_secs / speed))
    end

    parts[#parts+1] = S .. string.format("Total playlist:   %s", hms(total_secs))

    if math.abs(speed - 1.0) > 0.01 then
        parts[#parts+1] = GS .. string.format("Total (%.2fx):     %s", speed, hms(total_secs / speed))
    end

    if unknown_count > 0 then
        parts[#parts+1] = HI .. string.format("(%d item(s) duration unknown)", unknown_count)
    end

    -- ── render ────────────────────────────────────────────────────────────
    ov      = mp.create_osd_overlay("ass-events")
    ov.data = table.concat(parts, "\\N")
    ov:update()

    -- auto-dismiss after 7 seconds
    ov_timer = mp.add_timeout(7, function()
        ov_timer = nil
        dismiss_overlay()
    end)
end

mp.add_forced_key_binding("y", "playlist_info", show_playlist_info)
