#!/usr/bin/env bash
#  ____  _          _ _
# / ___|| |__   ___| | |
# \___ \| '_ \ / _ \ | |
#  ___) | | | |  __/ | |
# |____/|_| |_|\___|_|_|
#

# DESC: Matrix ZSH Ecosystem & Shell Installer
# Provides interactive setup for bash, fish, and a fully provisioned ZSH ecosystem.

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

Matrix ZSH Ecosystem & Shell Installer.
Interactively sets up your default shell and installs necessary dependencies.

Options:
  -h, --help    Show this help message and exit
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi

# We temporarily suspend exit-on-error for the Gum UI cancellation to work gracefully
set +e

sleep 1
clear
figlet -f smslant "Shell Setup"

echo ":: Please select your preferred shell"
echo
shell=$(gum choose "bash" "zsh" "fish" "Cancel")

# Resume strict mode
set -e

# -----------------------------------------------------
# Activate bash
# -----------------------------------------------------
if [[ $shell == "bash" ]]; then
    
    info "Setting shell to bash..."
    while ! sudo chsh -s $(which bash) $USER; do
        warn "Authentication failed. Please try again."
        sleep 1
    done
    success "Shell is now bash."

    info "Installing oh-my-posh..."
    curl -s https://ohmyposh.dev/install.sh | bash -s

    gum spin --spinner dot --title "Please reboot your system." -- sleep 3

# -----------------------------------------------------
# Activate fish
# -----------------------------------------------------
elif [[ $shell == "fish" ]]; then

    echo ":: Please install fish manually for your distro (if not yet done) before proceeding."
    if gum confirm "Is fish installed on your system?"; then

        info "Setting shell to fish..."
        while ! sudo chsh -s $(which fish) $USER; do
            warn "Authentication failed. Please try again."
            sleep 1
        done
        success "Shell is now fish."

        info "Installing oh-my-posh..."
        curl -s https://ohmyposh.dev/install.sh | bash -s

        gum spin --spinner dot --title "Please reboot your system." -- sleep 3
    fi

# -----------------------------------------------------
# Activate zsh
# -----------------------------------------------------
elif [[ $shell == "zsh" ]]; then

    info "Setting shell to zsh..."
    while ! sudo chsh -s $(which zsh) $USER; do
        warn "Authentication failed. Please try again."
        sleep 1
    done
    success "Shell is now zsh."

    # Install System Dependencies
    info "Installing ZSH ecosystem dependencies (paru)..."
    paru -S --needed --noconfirm zsh eza fastfetch fzf tty-clock zoxide || warn "Failed to install some dependencies. Please check paru."

    # Install Oh-My-Posh (fallback / option)
    info "Installing oh-my-posh..."
    curl -s https://ohmyposh.dev/install.sh | bash -s || true

    # Install Oh-My-Zsh
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        info "Installing oh-my-zsh..."
        sh -c "$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    else
        success "oh-my-zsh already installed"
    fi

    # ZSH Custom directory
    ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}

    # Installing zsh-autosuggestions
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
        info "Installing zsh-autosuggestions..."
        git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    else
        success "zsh-autosuggestions already installed"
    fi

    # Installing zsh-syntax-highlighting
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
        info "Installing zsh-syntax-highlighting..."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
    else
        success "zsh-syntax-highlighting already installed"
    fi

    # Installing fast-syntax-highlighting
    if [ ! -d "$ZSH_CUSTOM/plugins/fast-syntax-highlighting" ]; then
        info "Installing fast-syntax-highlighting..."
        git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git "$ZSH_CUSTOM/plugins/fast-syntax-highlighting"
    else
        success "fast-syntax-highlighting already installed"
    fi
    
    # Installing Powerlevel10k
    if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
        info "Installing Powerlevel10k theme..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
    else
        success "Powerlevel10k already installed"
    fi

    # Prompt Theme Selection
    set +e
    echo
    echo ":: Which ZSH Prompt Theme would you like to use?"
    ZSH_THEME_CHOICE=$(gum choose "Oh-My-Posh (Zen)" "Powerlevel10k" "Keep Current")
    set -e
    
    CUSTOMIZATION_FILE="$HOME/.config/zshrc/20-customization"
    if [ -f "$CUSTOMIZATION_FILE" ]; then
        if [[ "$ZSH_THEME_CHOICE" == "Powerlevel10k" ]]; then
            info "Configuring Powerlevel10k..."
            # Comment out oh-my-posh
            sed -i 's/^eval "$(oh-my-posh/# eval "$(oh-my-posh/g' "$CUSTOMIZATION_FILE"
            # Ensure ZSH_THEME is set to p10k
            if grep -q "ZSH_THEME=\"powerlevel10k/powerlevel10k\"" "$CUSTOMIZATION_FILE"; then
                sed -i 's/^# ZSH_THEME="powerlevel10k\/powerlevel10k"/ZSH_THEME="powerlevel10k\/powerlevel10k"/g' "$CUSTOMIZATION_FILE"
            else
                echo 'ZSH_THEME="powerlevel10k/powerlevel10k"' >> "$CUSTOMIZATION_FILE"
            fi
        elif [[ "$ZSH_THEME_CHOICE" == "Oh-My-Posh (Zen)" ]]; then
            info "Configuring Oh-My-Posh..."
            # Uncomment oh-my-posh zen
            sed -i 's/^# eval "$(oh-my-posh init zsh --config $HOME\/.config\/ohmyposh\/zen.toml)"/eval "$(oh-my-posh init zsh --config $HOME\/.config\/ohmyposh\/zen.toml)"/g' "$CUSTOMIZATION_FILE"
            # Comment out p10k
            sed -i 's/^ZSH_THEME="powerlevel10k\/powerlevel10k"/# ZSH_THEME="powerlevel10k\/powerlevel10k"/g' "$CUSTOMIZATION_FILE"
        fi
    fi

    # Deploy Modular .zshrc Loader
    info "Deploying Matrix .zshrc modular loader..."
    cat << 'EOF' > "$HOME/.zshrc"
#            _
#    _______| |__  _ __ ___
#   |_  / __| '_ \| '__/ __|
#  _ / /\__ \ | | | | | (__
# (_)___|___/_| |_|_|  \___|
#
# -----------------------------------------------------
# Matrix zshrc loader
# -----------------------------------------------------

# DON'T CHANGE THIS FILE

# You can define your custom configuration by adding
# files in ~/.config/zshrc
# or by creating a folder ~/.config/zshrc/custom
# with copies of files from ~/.config/zshrc
# You can also create a .zshrc_custom file in your home directory
# -----------------------------------------------------

# -----------------------------------------------------
# Load modular configuration
# -----------------------------------------------------

for f in ~/.config/zshrc/*; do
    if [ ! -d $f ]; then
        c=$(echo $f | sed -e "s=.config/zshrc=.config/zshrc/custom=")
        [[ -f $c ]] && source $c || source $f
    fi
done

# -----------------------------------------------------
# Load single customization file (if exists)
# -----------------------------------------------------

if [ -f ~/.zshrc_custom ]; then
    source ~/.zshrc_custom
fi
EOF

    # Inject p10k source hook into .zshrc if they chose p10k
    if [[ "$ZSH_THEME_CHOICE" == "Powerlevel10k" ]]; then
        if ! grep -q "p10k.zsh" "$HOME/.zshrc"; then
            echo -e "\n# To customize prompt, run \`p10k configure\` or edit ~/.p10k.zsh." >> "$HOME/.zshrc"
            echo "[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh" >> "$HOME/.zshrc"
        fi
    fi

    success "ZSH ecosystem provisioned successfully!"
    gum spin --spinner dot --title "Please reboot your system (or log out and in) to apply shell changes." -- sleep 3

# -----------------------------------------------------
# Cancel
# -----------------------------------------------------
else
    echo ":: Changing shell canceled"
    exit 0
fi
