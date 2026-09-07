#!/usr/bin/env python3
import subprocess
import os
import re
import json
import sys
import time

MUSIC_DIR = os.path.expanduser("~/Music/some_good_time")
PLAIN = '--plain' in sys.argv

EMPTY_JSON = json.dumps({"text": "", "class": "stopped", "tooltip": ""})
EMPTY_PLAIN = ""

def empty():
    print(EMPTY_PLAIN if PLAIN else EMPTY_JSON, flush=True)

def is_playing():
    result = subprocess.run(['mpc'], capture_output=True, text=True)
    return '[playing]' in result.stdout

def lyrics_enabled():
    return os.path.exists('/tmp/lyrics_enabled')

def get_mpc_info_batched():
    # Batch all data into a single, efficient MPC call
    # Format: filename|title|artist|album|date
    result = subprocess.run(['mpc', '-f', '%file%|%title%|%artist%|%album%|%date%'], capture_output=True, text=True)
    lines = result.stdout.strip().split('\n')
    
    if len(lines) < 2:
        return None, None, None, None, None, None
        
    data = lines[0].split('|')
    if len(data) != 5:
        return None, None, None, None, None, None
        
    filename, title, artist, album, date = data
    
    time_match = re.search(r'(\d+):(\d+\.\d+|\d+)/\d+:\d+', lines[1])
    if not time_match:
        return None, None, None, None, None, None
        
    elapsed = int(time_match.group(1)) * 60 + float(time_match.group(2))
    return filename, elapsed, title, artist, album, date

def parse_lrc(lrc_path, elapsed):
    with open(lrc_path, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
    lines = []
    for line in content.split('\n'):
        match = re.match(r'\[(\d+):(\d+(?:\.\d+)?)\](.*)', line)
        if match:
            t = int(match.group(1)) * 60 + float(match.group(2))
            text = match.group(3).strip()
            if text:
                lines.append((t, text))
    lines.sort(key=lambda x: x[0])
    current_line = ""
    for t, text in lines:
        if t <= elapsed:
            current_line = text
        else:
            break
    return current_line

def main():
    while True:
        if not is_playing() or not lyrics_enabled():
            empty()
        else:
            filename, elapsed, title, artist, album, date = get_mpc_info_batched()
            if not filename or elapsed is None:
                empty()
            else:
                base = os.path.splitext(filename)[0]
                lrc_path = os.path.join(MUSIC_DIR, base + ".lrc")

                if not os.path.exists(lrc_path):
                    empty()
                else:
                    line = parse_lrc(lrc_path, elapsed)

                    if PLAIN:
                        print(line, flush=True)
                    else:
                        tooltip = f"{title}\n{artist}\n{album}  •  {date}"
                        print(json.dumps({"text": line, "class": "playing", "tooltip": tooltip}), flush=True)
        
        if "--follow" in sys.argv:
            time.sleep(1)
        else:
            break

if __name__ == "__main__":
    main()
