#!/usr/bin/env bash
# __     __         _ 
# \ \   / /_ _ ____(_)
#  \ \ / / _` |_  / | 
#   \ V / (_| |/ /| | 
#    \_/ \__,_/___|_| 
#                     

# DESC: Installs peripherals like custom fonts and hardware configurations

set -Eeuo pipefail
trap 'echo -e "\e[31m[!] Error: Script failed on line $LINENO\e[0m" >&2' ERR

info()    { echo -e "\e[34m[*]\e[0m $1"; }
warn()    { echo -e "\e[33m[!]\e[0m $1"; }
die()     { echo -e "\e[31m[✘]\e[0m $1" >&2; exit 1; }
success() { echo -e "\e[32m[✔]\e[0m $1"; }

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Installs peripherals, currently starting with custom fonts (Knight Warrior, Hyper Oxide).

Options:
  -h, --help    Show this help message and exit
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi

set +e
sleep 1
clear
figlet -f smslant "Peripherals"

if ! gum confirm "Install peripheral drivers and custom fonts?"; then
    echo ":: Peripheral setup canceled."
    exit 0
fi
set -e

info "Ensuring unzip and fontconfig are installed..."
if ! command -v unzip &> /dev/null || ! command -v fc-cache &> /dev/null; then
    paru -S --needed --noconfirm unzip fontconfig
fi

# Font Installation
FONT_DIR="$HOME/.local/share/fonts/MatrixCustom"
mkdir -p "$FONT_DIR"

info "Downloading fonts into a secure temporary space..."
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"

info "Fetching Knight Warrior..."
curl -sSL -o knight_warrior.zip 'https://dl.dafont.com/dl/?f=knight_warrior'
unzip -q -o knight_warrior.zip

info "Fetching Hyper Oxide..."
curl -sSL -o hyper_oxide.zip 'https://www.1001fonts.com/download/hyper-oxide.zip'
unzip -q -o hyper_oxide.zip

info "Installing Font Files..."
# The zip files extract exactly into the current directory as .otf and .ttf
find . -type f \( -iname "*.ttf" -o -iname "*.otf" \) -exec cp {} "$FONT_DIR/" \;

info "Cleaning up temporary files..."
cd "$HOME"
rm -rf "$TMP_DIR"

info "Rebuilding the font cache..."
fc-cache -fv "$FONT_DIR"

success "Peripherals and Fonts successfully installed!"
gum spin --spinner dot --title "Done!" -- sleep 2
