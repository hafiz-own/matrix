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
        mp.command("cycle pause")
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
            mp.command("cycle pause")
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
--
-- Durations of other playlist items come from ffprobe, run ASYNCHRONOUSLY
-- one at a time and cached for the session. The overlay appears at once and
-- fills in as probes finish; nothing blocks mpv's script thread (the old
-- synchronous loop froze every binding of this script, SPACE included,
-- until all items were probed). Files that were played are cached from
-- mpv's own duration, so they are never probed.
-- =========================================================================

local durations = {}   -- filename -> seconds | false (unknown, don't retry)
local probing   = nil  -- filename currently being probed
local queue     = {}   -- filenames waiting to be probed

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

local function is_remote(filename)
    return filename:find("^%a[%w+.-]*://") ~= nil or filename:match("^magnet:") ~= nil
end

-- Cache the duration of whatever mpv plays (free: no probe needed later)
mp.register_event("file-loaded", function()
    local path = mp.get_property("path")
    local dur  = mp.get_property_number("duration")
    if path and dur then durations[path] = dur end
end)

-- ── overlay state ─────────────────────────────────────────────────────────

local ov       = nil   -- mp.OsdOverlay object
local ov_timer = nil   -- auto-hide timer

local function dismiss_overlay()
    if ov_timer then ov_timer:kill(); ov_timer = nil end
    if ov then ov:remove(); ov = nil end
    queue = {}         -- stop probing once nobody is looking (cache is kept)
end

local function render()
    if not ov then return end
    local playlist    = mp.get_property_native("playlist") or {}
    local current_pos = mp.get_property_number("playlist-pos", 0)   -- 0-indexed
    local speed       = mp.get_property_number("speed", 1.0)
    local duration    = mp.get_property_number("duration")
    local time_pos    = mp.get_property_number("time-pos")
    local current_1idx = current_pos + 1

    local remaining_secs, total_secs = 0, 0
    local unknown_count, pending_count = 0, 0

    for i, item in ipairs(playlist) do
        local dur
        if i == current_1idx then
            dur = duration
            if dur and time_pos then
                remaining_secs = remaining_secs + math.max(0, dur - time_pos)
            end
        else
            dur = durations[item.filename]
            if dur and i > current_1idx then
                remaining_secs = remaining_secs + dur
            end
        end
        if dur then
            total_secs = total_secs + dur
        elseif durations[item.filename] == nil and i ~= current_1idx then
            pending_count = pending_count + 1
        else
            unknown_count = unknown_count + 1
        end
    end

    -- \an9 = top-right anchor, \N = hard newline in ASS
    local W  = "{\\an9\\bord1.5\\shad1\\c&HFFFFFF&\\3c&H000000&\\fs22\\b1}"
    local N  = "{\\an9\\bord1.5\\shad1\\c&HFFFFFF&\\3c&H000000&\\fs20}"
    local G  = "{\\an9\\bord1.5\\shad1\\c&H80FF80&\\3c&H000000&\\fs20}"
    local S  = "{\\an9\\bord1.5\\shad1\\c&HCCCCCC&\\3c&H000000&\\fs18}"
    local GS = "{\\an9\\bord1.5\\shad1\\c&H80CC80&\\3c&H000000&\\fs18}"
    local HI = "{\\an9\\bord1\\shad0\\c&H8888FF&\\3c&H000000&\\fs16}"

    local parts = {}
    parts[#parts+1] = W .. string.format("Video %d of %d", current_1idx, #playlist)
    parts[#parts+1] = N .. string.format("Remaining (1x):   %s", hms(remaining_secs))
    if math.abs(speed - 1.0) > 0.01 then
        parts[#parts+1] = G .. string.format("Remaining (%.2fx): %s", speed, hms(remaining_secs / speed))
    end
    parts[#parts+1] = S .. string.format("Total playlist:   %s", hms(total_secs))
    if math.abs(speed - 1.0) > 0.01 then
        parts[#parts+1] = GS .. string.format("Total (%.2fx):     %s", speed, hms(total_secs / speed))
    end
    if pending_count > 0 then
        parts[#parts+1] = HI .. string.format("(measuring %d item(s)…)", pending_count)
    end
    if unknown_count > 0 then
        parts[#parts+1] = HI .. string.format("(%d item(s) duration unknown)", unknown_count)
    end

    ov.data = table.concat(parts, "\\N")
    ov:update()
end

-- Probe the next queued file; re-render when it finishes. One at a time.
local function probe_next()
    if probing then return end
    local filename = table.remove(queue, 1)
    while filename and durations[filename] ~= nil do
        filename = table.remove(queue, 1)
    end
    if not filename then return end

    probing = filename
    mp.command_native_async({
        name = "subprocess",
        args = { "ffprobe", "-v", "quiet", "-show_entries", "format=duration",
                 "-of", "default=noprint_wrappers=1:nokey=1", filename },
        capture_stdout = true,
        playback_only  = false,
    }, function(success, res)
        local dur = success and res and res.status == 0
                    and tonumber((res.stdout or ""):match("[%d%.]+"))
        durations[filename] = dur or false
        probing = nil
        render()
        probe_next()
    end)
end

local function show_playlist_info()
    -- Toggle off if already showing
    if ov then
        dismiss_overlay()
        return
    end

    local playlist = mp.get_property_native("playlist")
    if not playlist or #playlist == 0 then
        mp.osd_message("No playlist active.", 3)
        return
    end

    ov = mp.create_osd_overlay("ass-events")
    render()

    -- Queue local files whose duration we don't know yet (URLs are skipped)
    queue = {}
    for _, item in ipairs(playlist) do
        local f = item.filename
        if durations[f] == nil then
            if is_remote(f) then
                durations[f] = false
            else
                queue[#queue+1] = f
            end
        end
    end
    render()
    probe_next()

    -- auto-dismiss after 7 seconds
    ov_timer = mp.add_timeout(7, function()
        ov_timer = nil
        dismiss_overlay()
    end)
end

mp.add_forced_key_binding("y", "playlist_info", show_playlist_info)
