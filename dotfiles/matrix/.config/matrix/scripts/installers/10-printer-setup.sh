#!/bin/bash

# DESC: Hardens CUPS architecture and enforces secure IPP driverless printing.

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

Hardens CUPS architecture and enforces secure IPP driverless printing.

Options:
  -h, --help    Show this help message and exit
EOF
}

if [[ "\${1:-}" == "-h" || "\${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi

# DESC: Hardened CUPS Printer Architecture
echo "Applying Event-Driven CUPS Hardening Architecture..."

# 1. Install required packages
echo " -> Installing CUPS and cups-browsed..."
pacman -S --noconfirm --needed cups cups-browsed

# 2. Setup unprivileged dummy user for discovery
echo " -> Dropping root privileges for cups-browsed..."
mkdir -p /etc/sysusers.d/
echo "  -> Copying matrix-cups-sysusers.conf to /etc/sysusers.d/"
cp "$HOME/.config/matrix/scripts/system-configs/matrix-cups-sysusers.conf" /etc/sysusers.d/
systemd-sysusers

# 3. Apply Systemd sandboxing
echo " -> Applying strict kernel sandboxing to CUPS..."
mkdir -p /etc/systemd/system/cups-browsed.service.d/
echo "  -> Copying matrix-cups-browsed-systemd.conf to /etc/systemd/system/cups-browsed.service.d/10-matrix.conf"
cp "$HOME/.config/matrix/scripts/system-configs/matrix-cups-browsed-systemd.conf" /etc/systemd/system/cups-browsed.service.d/10-matrix.conf
systemctl daemon-reload

# 4. Disable vulnerable legacy protocols and force Driverless IPP
echo " -> Enforcing modern Driverless IPP discovery..."
echo "  -> Writing Driverless configuration block to /etc/cups/cups-browsed.conf"
bash -c 'cat << EOF > /etc/cups/cups-browsed.conf
# Keep state away from /var/cache/cups, which is writable by the account CUPS
# uses for print filters. cups-browsed is the only writer to this directory.
CacheDir /var/cache/cups-browsed

# Auto-create queues only for modern driverless IPP printers.
CreateIPPPrinterQueues Driverless
CreateRemoteCUPSPrinterQueues No
EOF'

# 5. Lock down group permissions in cups-files.conf
echo " -> Hardening CUPS file permissions..."
if grep -q "^SystemGroup" /etc/cups/cups-files.conf; then
    echo "  -> Modifying existing SystemGroup in /etc/cups/cups-files.conf"
    sed -i 's/^SystemGroup.*/SystemGroup cups-browsed sys root/' /etc/cups/cups-files.conf
else
    echo "  -> Appending SystemGroup cups-browsed sys root to /etc/cups/cups-files.conf"
    echo "SystemGroup cups-browsed sys root" | tee -a /etc/cups/cups-files.conf > /dev/null
fi

# 6. Enable and Start Services
echo " -> Enabling secure printing services..."
systemctl enable --now cups.service
systemctl enable --now cups-browsed.service

echo "Printer module installed and hardened successfully! You can now use modern Wi-Fi printers securely."
