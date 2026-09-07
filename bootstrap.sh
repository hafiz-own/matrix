#!/usr/bin/env bash
#  __  __       _        _
# |  \/  | __ _| |_ _ __(_)_  __
# | |\/| |/ _` | __| '__| \ \/ /
# | |  | | (_| | |_| |  | |>  <
# |_|  |_|\__,_|\__|_|  |_/_/\_\
#
# Matrix Dotfiles Bootstrap
# One command to go from bare Arch to a full Matrix desktop.
#
# Usage:
#   bash <(curl -s https://raw.githubusercontent.com/hafiz-own/matrix/main/bootstrap.sh)
#
# Or safer (audit first):
#   curl -o bootstrap.sh https://raw.githubusercontent.com/hafiz-own/matrix/main/bootstrap.sh
#   less bootstrap.sh
#   bash bootstrap.sh

set -Eeuo pipefail
trap 'echo -e "\n\e[31m[!] Bootstrap failed on line $LINENO. Check output above.\e[0m" >&2' ERR

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\e[31m'; GREEN='\e[32m'; YELLOW='\e[33m'; BLUE='\e[34m'; BOLD='\e[1m'; NC='\e[0m'
info()    { echo -e "${BLUE}[*]${NC} $1"; }
success() { echo -e "${GREEN}[✔]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
die()     { echo -e "${RED}[✘]${NC} $1" >&2; exit 1; }
step()    { echo -e "\n${BOLD}${BLUE}━━━ $1 ━━━${NC}"; }

# ── Config ───────────────────────────────────────────────────────────────────
REPO_URL="https://github.com/hafiz-own/matrix"
MATRIX_DIR="$HOME/.matrix"
DOTFILES_DIR="$MATRIX_DIR/dotfiles"

# ── Banner ───────────────────────────────────────────────────────────────────
clear
echo -e "${BOLD}"
cat << 'EOF'
  __  __       _        _
 |  \/  | __ _| |_ _ __(_)_  __
 | |\/| |/ _` | __| '__| \ \/ /
 | |  | | (_| | |_| |  | |>  <
 |_|  |_|\__,_|\__|_|  |_/_/\_\
EOF
echo -e "${NC}"
echo -e "  ${BOLD}Matrix Dotfiles Bootstrap${NC}"
echo -e "  Fresh Arch → Full Desktop in one shot\n"

# ── Stage 0: Preflight ───────────────────────────────────────────────────────
step "Stage 0: Preflight Checks"

# Not root
if [ "$EUID" -eq 0 ]; then
    die "Do NOT run as root. Run as your regular user with sudo access."
fi

# Arch Linux
if ! grep -qi "arch" /etc/os-release 2>/dev/null; then
    die "This bootstrap is designed for Arch Linux only."
fi

# Internet
if ! ping -c 1 -W 3 archlinux.org &>/dev/null; then
    die "No internet connection. Connect to a network and try again."
fi

success "Running as: $USER on Arch Linux with internet access."

# ── Stage 1: Bootstrap git ───────────────────────────────────────────────────
step "Stage 1: Ensuring git is available"

if ! command -v git &>/dev/null; then
    info "Installing git..."
    sudo pacman -S --noconfirm --needed git
fi
success "git ready."

# ── Stage 2: Clone the repo ──────────────────────────────────────────────────
step "Stage 2: Cloning Matrix dotfiles"

if [ -d "$MATRIX_DIR/.git" ]; then
    warn "~/.matrix already exists. Pulling latest..."
    git -C "$MATRIX_DIR" pull --ff-only
else
    info "Cloning into ~/.matrix ..."
    git clone "$REPO_URL" "$MATRIX_DIR"
fi
success "Matrix repo ready at ~/.matrix"

# ── Stage 3: Install paru ────────────────────────────────────────────────────
step "Stage 3: Installing paru (AUR helper)"

if command -v paru &>/dev/null; then
    success "paru already installed."
else
    info "Installing build dependencies..."
    sudo pacman -S --needed --noconfirm base-devel

    info "Building paru from AUR..."
    PARU_TMP=$(mktemp -d)
    git clone https://aur.archlinux.org/paru.git "$PARU_TMP"
    (cd "$PARU_TMP" && makepkg -si --noconfirm)
    rm -rf "$PARU_TMP"
    success "paru installed."
fi

# ── Stage 4: Install packages ────────────────────────────────────────────────
step "Stage 4: Installing core packages"

PACMAN_CORE="$MATRIX_DIR/packages/pacman-core.txt"
AUR_CORE="$MATRIX_DIR/packages/aur-core.txt"
PACMAN_OPT="$MATRIX_DIR/packages/pacman-optional.txt"
AUR_OPT="$MATRIX_DIR/packages/aur-optional.txt"

# Parse package files (strip comments and blank lines)
parse_pkgs() { grep -v '^\s*#' "$1" | grep -v '^\s*$' | tr '\n' ' '; }

info "Installing core pacman packages..."
# shellcheck disable=SC2046
sudo pacman -S --needed --noconfirm $(parse_pkgs "$PACMAN_CORE")
success "Core pacman packages installed."

info "Installing core AUR packages..."
# shellcheck disable=SC2046
paru -S --needed --noconfirm $(parse_pkgs "$AUR_CORE")
success "Core AUR packages installed."

# Optional packages
echo ""
read -rp "Install optional packages (browsers, apps, dev tools)? [y/N] " install_optional
if [[ "${install_optional,,}" == "y" ]]; then
    info "Installing optional pacman packages..."
    # shellcheck disable=SC2046
    sudo pacman -S --needed --noconfirm $(parse_pkgs "$PACMAN_OPT")

    info "Installing optional AUR packages..."
    # shellcheck disable=SC2046
    paru -S --needed --noconfirm $(parse_pkgs "$AUR_OPT")
    success "Optional packages installed."
else
    info "Skipping optional packages. You can install them later via install-extras.sh."
fi

# ── Stage 5: Deploy dotfiles via stow ────────────────────────────────────────
step "Stage 5: Deploying dotfiles via GNU Stow"

info "Stowing all dotfile packages..."
cd "$DOTFILES_DIR"
for pkg in */; do
    pkg="${pkg%/}"
    stow --target="$HOME" "$pkg" 2>/dev/null && echo "  ✔ $pkg" || warn "  Conflict in $pkg — skipping (run manually: stow --adopt $pkg)"
done
success "Dotfiles deployed. ~/.config entries are now symlinked into ~/.matrix/dotfiles/"


# ── Stage 6: Enable services ─────────────────────────────────────────────────
step "Stage 6: Enabling systemd services"

SERVICES=(NetworkManager bluetooth tuned)
for svc in "${SERVICES[@]}"; do
    if systemctl enable --now "$svc" &>/dev/null; then
        success "Enabled: $svc"
    else
        warn "Could not enable: $svc"
    fi
done

# Pipewire runs as user service
systemctl --user enable --now pipewire pipewire-pulse wireplumber 2>/dev/null && \
    success "Enabled: pipewire + wireplumber (user)" || \
    warn "Could not enable pipewire user services (will auto-start on next login)"

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}   Matrix Bootstrap Complete!               ${NC}"
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${GREEN}✔${NC}  Core packages installed"
echo -e "  ${GREEN}✔${NC}  Dotfiles deployed via stow"
echo -e "  ${GREEN}✔${NC}  System configs placed"
echo -e "  ${GREEN}✔${NC}  Services enabled"
echo ""
echo -e "  ${BOLD}Next steps:${NC}"
echo -e "  1. Run extras:  ${BOLD}~/.matrix/install-extras.sh${NC}"
echo -e "     (shell setup, snapshots, fingerprint, NVIDIA, etc.)"
echo -e "  2. Reboot:      ${BOLD}reboot${NC}"
echo ""
