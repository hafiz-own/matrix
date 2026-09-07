#!/usr/bin/env bash

# DESC: Sets up system hibernation, configures GRUB, and detects swap partitions.

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

Sets up system hibernation, configures GRUB, and detects swap partitions.

Options:
  -h, --help    Show this help message and exit
EOF
}

if [[ "\${1:-}" == "-h" || "\${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi


set -euo pipefail

# DESC: Partition-Based Hibernation (GRUB)
echo "Applying Partition-Based Hibernation (GRUB)..."

# 1. Find the physical swap partition (ignoring zram)
SWAP_DEV=$(swapon --show=NAME,TYPE --noheadings | grep "partition" | grep -v "zram" | awk '{print $1}' | head -n 1 || true)
if [ -z "$SWAP_DEV" ]; then
    echo "Error: No physical swap partition found! Aborting hibernation setup."
    exit 1
fi
echo " -> Found physical swap partition: $SWAP_DEV"

# 2. Get the UUID of the swap partition
SWAP_UUID=$(blkid -s UUID -o value "$SWAP_DEV" || true)
if [ -z "$SWAP_UUID" ]; then
    echo "Error: Could not determine UUID for $SWAP_DEV. Aborting."
    exit 1
fi
echo " -> Swap UUID: $SWAP_UUID"

# 3. Add resume hook to mkinitcpio.conf
if grep -q "^HOOKS=.*resume" /etc/mkinitcpio.conf; then
    echo " -> 'resume' hook already exists in mkinitcpio.conf"
else
    echo " -> Injecting 'resume' hook into mkinitcpio.conf..."
    sudo sed -i 's/\(filesystems\)/resume \1/' /etc/mkinitcpio.conf
fi

# 4. Add resume=UUID parameter to GRUB
if ! grep -q "resume=UUID" /etc/default/grub; then
    echo " -> Injecting resume parameter into GRUB..."
    sudo sed -i "s/\(GRUB_CMDLINE_LINUX_DEFAULT=\"\)/\1resume=UUID=$SWAP_UUID /" /etc/default/grub
else
    echo " -> Updating existing resume parameter in GRUB..."
    sudo sed -i "s/resume=UUID=[^ \"]*/resume=UUID=$SWAP_UUID/" /etc/default/grub
fi

# 5. Rebuild System Configurations
echo " -> Rebuilding GRUB configuration..."
sudo grub-mkconfig -o /boot/grub/grub.cfg >/dev/null

echo " -> Rebuilding initramfs kernel image..."
sudo mkinitcpio -P >/dev/null

echo "Hibernation module installed successfully! Please reboot for changes to fully apply."
