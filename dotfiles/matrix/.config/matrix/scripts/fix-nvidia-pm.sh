#!/usr/bin/env bash
# NVIDIA dGPU runtime power management (needs root)
# Run with:  sudo bash ~/.config/matrix/scripts/fix-nvidia-pm.sh
#
# The driver already has fine-grained runtime D3 enabled
# (/proc/driver/nvidia/gpus/*/power), but the PCI device's
# power/control is "on", which forbids runtime suspend, so the MX550
# stays powered even when nothing uses it.
#
# Changes:
#   1. installs /etc/udev/rules.d/80-nvidia-pm.rules (sets power/control
#      to "auto" for NVIDIA GPUs when the driver binds)
#   2. sets power/control=auto on the current NVIDIA GPU right away
# Nothing else is touched. Undo: delete the rule file and reboot.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run with sudo"; exit 1; }

src="$(dirname "$(readlink -f "$0")")/system-configs/80-nvidia-pm.rules"
install -m 0644 "$src" /etc/udev/rules.d/80-nvidia-pm.rules
udevadm control --reload-rules
echo "==> installed /etc/udev/rules.d/80-nvidia-pm.rules"

for d in /sys/bus/pci/devices/*; do
    [[ "$(<"$d/vendor")" == "0x10de" && "$(<"$d/class")" == 0x03* ]] || continue
    echo auto > "$d/power/control"
    echo "==> ${d##*/}: power/control=$(<"$d/power/control")"
done
echo "Done. Check after ~15s idle: cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status  (want: suspended)"
