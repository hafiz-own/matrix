#!/usr/bin/env bash
# DESC: Fingerprint Authentication (Broadcom ControlVault 3 + PAM)
# 08-fingerprint-setup.sh
# Installs fprintd + Broadcom driver, configures sudo/polkit/hyprlock PAM,
# and patches hyprlock.conf for fingerprint unlock support.

# DESC: Configures fprintd for fingerprint authentication and sets up PAM.

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
Usage: \$(basename "\$0") [OPTIONS]

Configures fprintd for fingerprint authentication and sets up PAM.

Options:
  -h, --help    Show this help message and exit
EOF
}

if [[ "\${1:-}" == "-h" || "\${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi




# Pre-flight
if ! command -v paru &>/dev/null; then die "'paru' is not installed."; fi
if ! command -v gum &>/dev/null; then die "'gum' is not installed. Run: sudo pacman -S gum"; fi
if [ "$EUID" -eq 0 ]; then die "Do NOT run this as root. It uses sudo internally."; fi

echo ""
echo -e "\e[1m=========================================\e[0m"
echo -e "\e[1m  Matrix Fingerprint Authentication Setup\e[0m"
echo -e "\e[1m=========================================\e[0m"
echo ""
echo "  This script will:"
echo "   • Install fprintd + Broadcom ControlVault 3 driver"
echo "   • Configure fingerprint auth for sudo and polkit"
echo "   • Keep hyprlock's PAM password-only (hyprlock reads the sensor itself)"
echo "   • Keep the Broadcom reader out of USB autosuspend"
echo ""

if ! gum confirm "Proceed with fingerprint authentication setup?"; then
    echo "Aborted."
    exit 0
fi

# Step 1: Packages
echo ""
info "Installing fprintd..."
sudo pacman -S --needed --noconfirm fprintd

info "Installing Broadcom ControlVault 3 driver from AUR..."
info "(You may be prompted to review the PKGBUILD — this is a proprietary binary blob)"
paru -S --needed libfprint-2-tod1-broadcom

# Step 2: Validate sensor
echo ""
info "Checking that the fingerprint sensor is detected..."

DEVICE_OUTPUT=$(fprintd-list "$USER" 2>&1 || true)
DEVICE_COUNT=$(echo "$DEVICE_OUTPUT" | grep -c "Device at" || true)

if [ "$DEVICE_COUNT" -eq 0 ]; then
    echo ""
    warn "fprintd found no fingerprint devices!"
    warn "Possible fixes:"
    warn "  1. Reboot and re-run this script"
    warn "  2. Check: journalctl -b | grep -i fprintd"
    die "Aborting: no fingerprint device available."
fi
success "Sensor detected! ($DEVICE_COUNT device(s) found)"

# Step 3: PAM inject helper (idempotent)
pam_inject() {
    local FILE="$1"
    local LINE="auth       sufficient   pam_fprintd.so"

    if grep -q "pam_fprintd.so" "$FILE" 2>/dev/null; then
        info "Already configured: $FILE — skipping"
        return
    fi

    if [ ! -f "${FILE}.bak-fingerprint" ]; then
        sudo cp "$FILE" "${FILE}.bak-fingerprint"
        info "Backed up: ${FILE}.bak-fingerprint"
    fi

    echo "  -> Inserting: '${LINE}' into ${FILE}"
    sudo sed -i "0,/^auth/s|^auth|${LINE}\nauth|" "$FILE"
    success "Configured: $FILE"
}

# Step 4: sudo PAM
echo ""
info "Configuring PAM for sudo..."
pam_inject /etc/pam.d/sudo

# Step 5: polkit PAM
echo ""
info "Configuring PAM for polkit..."

if [ ! -f /etc/pam.d/polkit-1 ]; then
    if [ -f /usr/lib/pam.d/polkit-1 ]; then
        sudo cp /usr/lib/pam.d/polkit-1 /etc/pam.d/polkit-1
        info "Copied /usr/lib/pam.d/polkit-1 → /etc/pam.d/polkit-1"
    else
        warn "No upstream polkit-1 PAM file found — creating minimal one"
        sudo tee /etc/pam.d/polkit-1 >/dev/null <<'EOF'
#%PAM-1.0
auth       include      system-auth
account    include      system-auth
password   include      system-auth
session    include      system-auth
EOF
    fi
fi
pam_inject /etc/pam.d/polkit-1

# Step 6: hyprlock PAM: password only
# hyprlock.conf (in the repo) enables hyprlock's native fingerprint auth,
# which talks to fprintd over D-Bus. If the hyprlock PAM stack also runs
# pam_fprintd, both claim the reader ("Device was already claimed"), the
# prompt shows only sometimes and hyprlock lingers after unlocking.
echo ""
info "Configuring PAM for hyprlock (password only)..."
if [ -f /etc/pam.d/hyprlock ] && grep -q "pam_fprintd.so" /etc/pam.d/hyprlock; then
    sudo cp /etc/pam.d/hyprlock "/etc/pam.d/hyprlock.bak-$(date +%Y%m%d%H%M%S)"
fi
sudo tee /etc/pam.d/hyprlock >/dev/null <<'EOF'
# PAM configuration file for hyprlock
# Fingerprint is handled by hyprlock itself via D-Bus (fprintd).
# This stack handles password authentication only.
auth    include   login
EOF
success "Configured: /etc/pam.d/hyprlock"

# Step 7: keep the reader awake
# libfprint lets the Broadcom ControlVault 3 (0a5c:5843) autosuspend, after
# which it can stop answering until it is replugged.
echo ""
info "Disabling USB autosuspend for the Broadcom reader..."
sudo tee /etc/udev/rules.d/90-broadcom-fingerprint-power.rules >/dev/null <<'EOF'
# Override libfprint's autosuspend for Broadcom ControlVault 3 (0a5c:5843).
ACTION=="add|change", SUBSYSTEM=="usb", ATTRS{idVendor}=="0a5c", ATTRS{idProduct}=="5843", TEST=="power/control", ATTR{power/control}="on"
EOF
sudo udevadm control --reload-rules
sudo udevadm trigger --action=change --subsystem-match=usb --attr-match=idVendor=0a5c
success "Reader kept out of autosuspend"

# Done
echo ""
echo -e "\e[1m\e[32m=========================================\e[0m"
echo -e "\e[1m\e[32m  Fingerprint Authentication Installed!  \e[0m"
echo -e "\e[1m\e[32m=========================================\e[0m"
echo ""
echo "  ✅  sudo      → tap sensor instead of typing password"
echo "  ✅  polkit    → tap sensor for GUI privilege prompts"
echo "  ✅  hyprlock  → tap sensor to unlock the screen (built into hyprlock.conf)"
echo ""
echo "  Next step: enroll your fingerprints"
echo "  Run: fingerprint enroll"
echo ""
