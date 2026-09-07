#!/usr/bin/env bash
# __     __         _ 
# \ \   / /_ _ ____(_)
#  \ \ / / _` |_  / | 
#   \ V / (_| |/ /| | 
#    \_/ \__,_/___|_| 
#                     

# DESC: Supercharges Yazi with premium visual and navigation plugins

set -Eeuo pipefail
trap 'echo -e "\e[31m[!] Error: Script failed on line $LINENO\e[0m" >&2' ERR

info()    { echo -e "\e[34m[*]\e[0m $1"; }
warn()    { echo -e "\e[33m[!]\e[0m $1"; }
die()     { echo -e "\e[31m[✘]\e[0m $1" >&2; exit 1; }
success() { echo -e "\e[32m[✔]\e[0m $1"; }

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Supercharges Yazi with Git integration, jump motions, smart-enter, and full-borders.

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
figlet -f smslant "Yazi Setup"

if ! gum confirm "Supercharge Yazi (Git, Borders, Smart Enter)?"; then
    echo ":: Yazi setup canceled."
    exit 0
fi
set -e

if ! command -v yazi &> /dev/null; then
    info "Installing Yazi..."
    paru -S --needed --noconfirm yazi
fi

info "Installing plugins via Yazi package manager..."
for plugin in "git" "full-border" "jump-to-char" "smart-enter"; do
    ya pkg add "yazi-rs/plugins:$plugin" || warn "Plugin $plugin already exists or failed, skipping..."
done
ya pkg upgrade

YAZI_DIR="$HOME/.config/yazi"
mkdir -p "$YAZI_DIR"

info "Configuring init.lua..."
cat << 'EOF' > "$YAZI_DIR/init.lua"
require("full-border"):setup {
    type = ui.Border.ROUNDED,
}
require("git"):setup {
    order = 1500,
}
EOF

info "Configuring yazi.toml..."
# Initialize or append to yazi.toml
if [[ ! -f "$YAZI_DIR/yazi.toml" ]]; then
    touch "$YAZI_DIR/yazi.toml"
fi

if ! grep -q "plugin.prepend_fetchers" "$YAZI_DIR/yazi.toml"; then
cat << 'EOF' >> "$YAZI_DIR/yazi.toml"

[[plugin.prepend_fetchers]]
url   = "*"
run   = "git"
group = "git"

[[plugin.prepend_fetchers]]
url   = "*/"
run   = "git"
group = "git"
EOF
else
    warn "plugin.prepend_fetchers already exists in yazi.toml, skipping fetcher injection."
fi

info "Configuring keymap.toml..."
if [[ ! -f "$YAZI_DIR/keymap.toml" ]]; then
    touch "$YAZI_DIR/keymap.toml"
fi

if ! grep -q "plugin smart-enter" "$YAZI_DIR/keymap.toml"; then
cat << 'EOF' >> "$YAZI_DIR/keymap.toml"

[[mgr.prepend_keymap]]
on   = "l"
run  = "plugin smart-enter"
desc = "Enter the child directory, or open the file"

[[mgr.prepend_keymap]]
on   = "<Enter>"
run  = "plugin smart-enter"
desc = "Enter the child directory, or open the file"

[[mgr.prepend_keymap]]
on   = "f"
run  = "plugin jump-to-char"
desc = "Jump to char"
EOF
else
    warn "smart-enter already exists in keymap.toml, skipping keymap injection."
fi

success "Yazi ecosystem fully provisioned!"
gum spin --spinner dot --title "Done! Open yazi to test." -- sleep 2
