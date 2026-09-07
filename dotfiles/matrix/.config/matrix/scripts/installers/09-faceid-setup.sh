#!/usr/bin/env bash
# DESC: Face Authentication (facelock)
# Installs facelock and launches its interactive setup wizard.

# DESC: Installs and configures facelock for facial recognition authentication.

# Fail fast, fail loud
set -Eeuo pipefail
trap 'echo -e "\e[31m[!] Error: Script failed on line \$LINENO\e[0m" >&2' ERR

# Standard logging functions
info()    { echo -e "\e[34m[*]\e[0m \$1"; }
warn()    { echo -e "\e[33m[!]\e[0m \$1"; }
die()     { echo -e "\e[31m[✘]\e[0m \$1" >&2; exit 1; }
success() { echo -e "\e[32m[✔]\e[0m \$1"; }

# Help Menu
show_help() {
    cat << EOF
Usage: \$(basename "\$0") [OPTIONS]

Installs and configures facelock for facial recognition authentication.

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
if ! command -v gum &>/dev/null; then die "'gum' is not installed."; fi

echo ""
echo -e "\e[1m=========================================\e[0m"
echo -e "\e[1m  Matrix Face ID Authentication Setup    \e[0m"
echo -e "\e[1m=========================================\e[0m"
echo ""
echo "  This script will:"
echo "   • Install the 'facelock' daemon"
echo "   • Launch the interactive setup wizard"
echo ""
echo "  Note: The wizard will automatically configure your camera,"
echo "  download the AI models, and set up PAM for sudo and hyprlock."
echo ""

if ! gum confirm "Proceed with Face ID setup?"; then
    echo "Aborted."
    exit 0
fi

echo ""
info "Installing facelock from AUR..."
paru -S --needed facelock

echo ""
info "Launching facelock setup wizard..."
echo "Please follow the on-screen prompts to enroll your face."
echo ""
sudo facelock setup

echo ""
echo -e "\e[1m\e[32m=========================================\e[0m"
echo -e "\e[1m\e[32m  Face ID Authentication Installed!      \e[0m"
echo -e "\e[1m\e[32m=========================================\e[0m"
echo ""
echo "  To manage your face models later, you can use the 'faceid' command:"
echo "    faceid enroll   - Add another face model"
echo "    faceid test     - Test recognition"
echo "    faceid status   - Check system status"
echo ""
