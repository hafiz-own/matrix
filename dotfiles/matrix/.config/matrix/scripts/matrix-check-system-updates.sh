#!/usr/bin/env bash
#  _   _           _       _             
# | | | |_ __   __| | __ _| |_ ___  ___  
# | | | | '_ \ / _` |/ _` | __/ _ \/ __| 
# | |_| | |_) | (_| | (_| | ||  __/\__ \ 
#  \___/| .__/ \__,_|\__,_|\__\___||___/ 
#       |_|                              
#  

# DESC: Checks for system package updates asynchronously.

# Fail fast, fail loud
set -Eeuo pipefail
trap 'echo -e "\e[31m[!] Error: Script failed on line $LINENO\e[0m" >&2' ERR

# Standard logging functions
info()    { echo -e "\e[34m[*]\e[0m $1"; }
warn()    { echo -e "\e[33m[!]\e[0m $1"; }
die()     { echo -e "\e[31m[✘]\e[0m $1" >&2; exit 1; }
success() { echo -e "\e[32m[✔]\e[0m $1"; }

# Help Menu
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Checks for system package updates asynchronously.

Options:
  -h, --help    Show this help message and exit
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi


# Check if command exists
_checkCommandExists() {
    command -v "$1" &> /dev/null
}

# One check at a time (waybar can fire it on start and on signal at once):
# wait for a running instance instead of counting processes with ps|grep.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/matrix-check-system-updates.lock"
flock 9

# ----------------------------------------------------- 
# Check for updates
# ----------------------------------------------------- 

os_type="unknown"

# Arch
if _checkCommandExists "pacman"; then
    os_type="arch"
    check_lock_files() {
        local pacman_lock="/var/lib/pacman/db.lck"
        local checkup_lock="${TMPDIR:-/tmp}/checkup-db-${UID}/db.lck"

        while [ -f "$pacman_lock" ] || [ -f "$checkup_lock" ]; do
            sleep 1
        done
    }

    check_lock_files

    yay_installed="false"
    paru_installed="false"
    updates_aur=0

    if _checkCommandExists "yay"; then
        yay_installed="true"
    fi
    if _checkCommandExists "paru"; then
        paru_installed="true"
    fi
    # Prefer yay when both are installed (aur_helper was left unset then)
    if [[ $yay_installed == "true" ]]; then
        aur_helper="yay"
    elif [[ $paru_installed == "true" ]]; then
        aur_helper="paru"
    fi
    if [[ $yay_installed == "true" ]] || [[ $paru_installed == "true" ]]; then
        aur_output=$($aur_helper -Qum 2>/dev/null || true)   # exits 1 when nothing to update
        if [ -n "$aur_output" ]; then
            updates_aur=$(echo "$aur_output" | wc -l)
        else
            updates_aur=0
        fi
    fi
    pacman_output=$(checkupdates 2>/dev/null || true)       # exits 2 when nothing to update
    if [ -n "$pacman_output" ]; then
        updates_pacman=$(echo "$pacman_output" | wc -l)
    else
        updates_pacman=0
    fi
    updates=$((updates_pacman+updates_aur))
    
# Fedora
elif _checkCommandExists "dnf"; then
    os_type="fedora"
    updates=$(dnf check-update -q | grep -c "^[a-z0-9]" || true)
# Others
else
    updates=0
fi

# ----------------------------------------------------- 
# Output to Terminal
# ----------------------------------------------------- 

if [ "$updates" -eq 0 ]; then
    echo "No updates available."
else
    echo "System Updates Available: $updates"
    
    if [ "$os_type" == "arch" ]; then
        if [ "$updates_pacman" -gt 0 ]; then
            echo "  - Pacman: $updates_pacman"
        fi
        if [ "$updates_aur" -gt 0 ]; then
            echo "  - AUR: $updates_aur"
        fi
        
        echo ""
        if [ "$updates_pacman" -gt 0 ]; then
            echo "--- Pacman Updates ---"
            echo "$pacman_output"
        fi
        if [ "$updates_aur" -gt 0 ]; then
            echo "--- AUR Updates ---"
            echo "$aur_output"
        fi
    elif [ "$os_type" == "fedora" ]; then
        echo "  - DNF: $updates"
    fi
fi
