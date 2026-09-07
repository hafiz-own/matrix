#!/bin/env bash

# Cache User ID to prevent multiple subshell forks
USER_ID=$(id -u)
SOCKET_PATH="/run/user/$USER_ID/walker/walker.sock"
CONFIG_FILE="$HOME/.config/walker/config.toml"

# Fast native bash read to grab the theme without spawning `cat`
read -r walker_theme < "$HOME/.config/matrix/settings/walker-theme" 2>/dev/null || walker_theme="macos-spotlight-minimal-light"
if [ -z "$walker_theme" ]; then
    walker_theme="macos-spotlight-minimal-light"
fi

# Fast native bash string parsing to extract current theme from TOML without spawning `grep`
while read -r line; do
    if [[ "$line" == theme\ =\ * ]]; then
        current_config_theme="${line#*\"}"
        current_config_theme="${current_config_theme%\"*}"
        break
    fi
done < "$CONFIG_FILE"

# Check if theme has changed
if [ "$walker_theme" != "$current_config_theme" ]; then
    echo ":: Theme changed from '$current_config_theme' to '$walker_theme'. Syncing config.toml... ::" >&2
    
    # Update theme value in config.toml
    sed -i "s/theme = \".*\"/theme = \"$walker_theme\"/" "$CONFIG_FILE"
    
    # Update empty providers setting (collapse list on minimal, show apps on non-minimal)
    if [[ "$walker_theme" =~ minimal|clean|spotlight ]]; then
        sed -i 's/empty = .*/empty = [] # providers to be queried when query is empty/' "$CONFIG_FILE"
    else
        sed -i 's/empty = .*/empty = ["desktopapplications"] # providers to be queried when query is empty/' "$CONFIG_FILE"
    fi
    
    # Restart the background service to apply new theme/config (using setsid to detach)
    pkill "^walker$"
    sleep 0.1
    setsid walker --gapplication-service >/dev/null 2>&1 &
    
    # Tightly poll for the socket (faster loop)
    for i in {1..20}; do
        if [ -S "$SOCKET_PATH" ]; then break; fi
        sleep 0.05
    done
    
    # Trigger the service via the socket, falling back to standard client if connection fails
    ncat -U "$SOCKET_PATH" >/dev/null 2>&1 || walker -t "$walker_theme" "$@"
    exit 0
fi

# Execute the walker command. If no arguments are passed, trigger via Unix socket for near-instant toggle.
if [ $# -eq 0 ] && [ -S "$SOCKET_PATH" ]; then
    if ! ncat -U "$SOCKET_PATH" >/dev/null 2>&1; then
        # Service is dead! Auto-heal by restarting it in the background
        echo ":: Walker service is dead. Restarting service... ::" >&2
        pkill "^walker$"
        sleep 0.1
        setsid walker --gapplication-service >/dev/null 2>&1 &
        walker -t "$walker_theme" "$@"
    fi
else
    # Auto-start service if the socket file does not exist
    if [ ! -S "$SOCKET_PATH" ]; then
        echo ":: Walker service not running. Starting service... ::" >&2
        setsid walker --gapplication-service >/dev/null 2>&1 &
    fi
    walker -t "$walker_theme" "$@"
fi
