#!/usr/bin/env bash
#  _   ___   _____ ____ ___    _
# | \ | \ \ / /_ _|  _ \_ _| / \
# |  \| |\ V / | || | | | | / _ \
# | |\  | | |  | || |_| | |/ ___ \
# |_| \_| |_| |___|____/___/_/   \_\
#

# DESC: NVIDIA Driver Setup (nvidia-open + PRIME + Wayland)
# Installs the open NVIDIA kernel module, utilities, and configures
# Hyprland's NVIDIA environment overlay for hybrid graphics.

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
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Installs NVIDIA open drivers and configures Hyprland for hybrid GPU (PRIME).

Options:
  -h, --help    Show this help message and exit
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi

# ── Pre-flight checks ────────────────────────────────────────────────────────

if [ "$EUID" -eq 0 ]; then
    die "Do NOT run this as root. It uses sudo internally."
fi

if ! command -v paru &>/dev/null; then
    die "'paru' is not installed. Run the base bootstrap first."
fi

if ! command -v gum &>/dev/null; then
    die "'gum' is not installed. Run: sudo pacman -S gum"
fi

# ── GPU Detection ────────────────────────────────────────────────────────────

set +e
NVIDIA_BUS=$(lspci 2>/dev/null | grep -iE "NVIDIA|GeForce|Quadro|RTX|GTX")
set -e

sleep 1
clear
figlet -f smslant "NVIDIA Setup"

echo ""
echo -e "\e[1m============================================\e[0m"
echo -e "\e[1m   Matrix NVIDIA Driver Setup              \e[0m"
echo -e "\e[1m============================================\e[0m"
echo ""

if [ -z "$NVIDIA_BUS" ]; then
    warn "No NVIDIA GPU detected via lspci."
    warn "Detected GPUs:"
    lspci 2>/dev/null | grep -iE "VGA|3D|Display" | sed 's/^/    /'
    echo ""
    if ! gum confirm "No NVIDIA GPU found. Proceed anyway?"; then
        echo ":: NVIDIA setup cancelled."
        exit 0
    fi
else
    info "NVIDIA GPU detected:"
    echo "$NVIDIA_BUS" | sed 's/^/    /'
    echo ""
fi

# ── Confirm ──────────────────────────────────────────────────────────────────

echo "  This script will:"
echo "   • Enable the multilib repository (if not already enabled)"
echo "   • Install: nvidia-open, nvidia-utils, nvidia-settings, nvidia-prime"
echo "   • Install: vulkan-nouveau (Nouveau Vulkan fallback)"
echo "   • Regenerate the initramfs (mkinitcpio)"
echo "   • Activate Hyprland's NVIDIA environment overlay"
echo ""

set +e
if ! gum confirm "Proceed with NVIDIA driver installation?"; then
    echo ":: NVIDIA setup cancelled."
    exit 0
fi
set -e

# ── Enable multilib ───────────────────────────────────────────────────────────

info "Checking multilib repository..."
if grep -q "^\[multilib\]" /etc/pacman.conf; then
    success "multilib already enabled."
else
    info "Enabling multilib in /etc/pacman.conf..."
    sudo sed -i '/^#\[multilib\]/{
        s/^#//
        n
        s/^#//
    }' /etc/pacman.conf
    success "multilib enabled."
fi

# ── Install packages ──────────────────────────────────────────────────────────

info "Syncing pacman databases..."
sudo pacman -Sy --noconfirm

info "Installing NVIDIA packages..."
sudo pacman -S --needed --noconfirm \
    nvidia-open \
    nvidia-utils \
    nvidia-settings \
    nvidia-prime \
    vulkan-nouveau

# ── mkinitcpio ────────────────────────────────────────────────────────────────

info "Regenerating initramfs..."

MKINIT_CONF="/etc/mkinitcpio.conf"
if grep -q "^MODULES=.*nouveau" "$MKINIT_CONF"; then
    warn "Found 'nouveau' in mkinitcpio MODULES — you may want to remove it to avoid conflicts."
fi

sudo mkinitcpio -P
success "Initramfs regenerated."

# ── Done ──────────────────────────────────────────────────────────────────────
# NOTE: Hyprland environment.lua is left on default.lua (iGPU by default).
# PRIME offload is used per-app via: matrix-use-gpu <command>
# This means the desktop runs on the iGPU and only specific apps are offloaded
# to the NVIDIA dGPU on demand. No global env changes needed.

echo ""
echo -e "\e[1m\e[32m============================================\e[0m"
echo -e "\e[1m\e[32m   NVIDIA Setup Complete!                  \e[0m"
echo -e "\e[1m\e[32m============================================\e[0m"
echo ""
echo "  ✅  nvidia-open       installed"
echo "  ✅  nvidia-utils      installed"
echo "  ✅  nvidia-settings   installed"
echo "  ✅  nvidia-prime      installed"
echo "  ✅  initramfs         regenerated"
echo ""
echo "  Mode: PRIME Offload (iGPU default, dGPU on-demand)"
echo "  Hyprland environment: unchanged (stays on iGPU)"
echo ""
echo "  To run an app on the NVIDIA GPU:"
echo "    matrix-use-gpu <application>"
echo "    matrix-use-gpu blender"
echo "    matrix-use-gpu glxinfo | grep renderer"
echo ""
gum spin --spinner dot --title "A reboot is required to load the NVIDIA kernel module." -- sleep 3
