#!/usr/bin/env python3
"""Synced-lyrics feed for the Waybar custom/lyrics module.

Talks to MPD over one persistent socket instead of spawning mpc:
  * lyrics toggled off  -> only stats /tmp/lyrics_enabled once a second
  * MPD not playing     -> blocks on `idle player` (no CPU, no polling)
  * MPD playing         -> one `status` round-trip per second
  * MPD not running     -> retries the connection every 5 seconds

Usage: lrcsync.py [--follow] [--plain]
"""
import json
import os
import re
import socket
import sys
import time

MUSIC_DIR = os.path.expanduser("~/Music/some_good_time")
STATE_FILE = "/tmp/lyrics_enabled"
MPD_HOST = os.environ.get("MPD_HOST", "localhost")
MPD_PORT = int(os.environ.get("MPD_PORT", "6600"))
PLAIN = "--plain" in sys.argv
FOLLOW = "--follow" in sys.argv
LRC_LINE = re.compile(r"\[(\d+):(\d+(?:\.\d+)?)\](.*)")

_last = None


def emit(text="", cls="stopped", tooltip=""):
    """Print only when the output changes (Waybar redraws on every line)."""
    global _last
    out = text if PLAIN else json.dumps({"text": text, "class": cls, "tooltip": tooltip})
    if out != _last or not FOLLOW:
        print(out, flush=True)
        _last = out


class MPD:
    def __init__(self):
        self.sock = socket.create_connection((MPD_HOST, MPD_PORT), timeout=5)
        self.sock.settimeout(None)
        self.rfile = self.sock.makefile("r", encoding="utf-8", errors="replace")
        if not self.rfile.readline().startswith("OK MPD"):
            raise ConnectionError("not an MPD server")

    def cmd(self, line):
        self.sock.sendall((line + "\n").encode())
        result = {}
        for raw in self.rfile:
            raw = raw.rstrip("\n")
            if raw == "OK":
                return result
            if raw.startswith("ACK"):
                raise ConnectionError(raw)
            key, _, val = raw.partition(": ")
            result[key] = val
        raise ConnectionError("connection closed")

    def close(self):
        try:
            self.sock.close()
        except OSError:
            pass


_lrc_cache = {}


def load_lrc(song_file):
    if song_file in _lrc_cache:
        return _lrc_cache[song_file]
    path = os.path.join(MUSIC_DIR, os.path.splitext(song_file)[0] + ".lrc")
    lines = []
    try:
        with open(path, encoding="utf-8", errors="ignore") as f:
            for raw in f:
                m = LRC_LINE.match(raw)
                if m and m.group(3).strip():
                    lines.append((int(m.group(1)) * 60 + float(m.group(2)), m.group(3).strip()))
    except OSError:
        pass
    lines.sort(key=lambda x: x[0])
    _lrc_cache.clear()  # keep only the current song
    _lrc_cache[song_file] = lines
    return lines


def current_line(lines, elapsed):
    cur = ""
    for t, text in lines:
        if t > elapsed:
            break
        cur = text
    return cur


def run_once(mpd):
    """Emit the current state. Returns True when MPD is playing."""
    status = mpd.cmd("status")
    if status.get("state") != "play":
        emit()
        return False
    song = mpd.cmd("currentsong")
    lines = load_lrc(song.get("file", ""))
    line = current_line(lines, float(status.get("elapsed", 0)))
    if not line:
        emit()
        return True
    tooltip = "{}\n{}\n{}  •  {}".format(
        song.get("Title", ""), song.get("Artist", ""), song.get("Album", ""), song.get("Date", ""))
    emit(line, "playing", tooltip)
    return True


def main():
    mpd = None
    while True:
        if not os.path.exists(STATE_FILE):
            if mpd:
                mpd.close()
                mpd = None
            emit()
            if not FOLLOW:
                return
            time.sleep(1)
            continue
        try:
            if mpd is None:
                mpd = MPD()
            playing = run_once(mpd)
            if not FOLLOW:
                return
            if playing:
                time.sleep(1)
            else:
                mpd.cmd("idle player")  # blocks until playback state changes
        except (OSError, ConnectionError):
            if mpd:
                mpd.close()
            mpd = None
            emit()
            if not FOLLOW:
                return
            time.sleep(5)


if __name__ == "__main__":
    main()
