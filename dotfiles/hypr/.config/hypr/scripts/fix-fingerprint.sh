#!/usr/bin/env bash
# Hyprlock fingerprint fix — system-level changes (needs root)
# Run with:  sudo bash ~/.config/hypr/scripts/fix-fingerprint.sh
#
# Why: hyprlock.conf enables hyprlock's native fingerprint auth (it talks to
# fprintd over D-Bus and drives $FPRINTPROMPT/$FPRINTFAIL). If the hyprlock
# PAM stack ALSO runs pam_fprintd, both claim the reader at lock time: the
# loser gets "Device was already claimed", so the prompt shows only
# sometimes, and pam_fprintd keeps hyprlock alive after an unlock.
#
# Changes:
#   1. /etc/pam.d/hyprlock  -> password only ("auth include login");
#      backup saved as /etc/pam.d/hyprlock.bak-<date>
#   2. udev rule keeping the Broadcom ControlVault 3 reader (0a5c:5843)
#      out of USB autosuspend, applied immediately
#   3. removes fprintd-resume.service if an earlier version of this script
#      installed it: hyprlock already releases the reader before sleep and
#      re-claims it after resume, and restarting fprintd on resume races that
#
# Nothing else in /etc/pam.d is touched (sudo/polkit keep pam_fprintd).
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run with sudo"; exit 1; }

echo "==> [1/3] /etc/pam.d/hyprlock: password only (fingerprint handled by hyprlock)"
if [[ -f /etc/pam.d/hyprlock ]] && grep -q pam_fprintd /etc/pam.d/hyprlock; then
    cp /etc/pam.d/hyprlock "/etc/pam.d/hyprlock.bak-$(date +%Y%m%d%H%M%S)"
fi
cat > /etc/pam.d/hyprlock << 'EOF'
# PAM configuration file for hyprlock
# Fingerprint is handled by hyprlock itself via D-Bus (fprintd).
# This stack handles password authentication only.
auth    include   login
EOF

echo "==> [2/3] udev: keep the fingerprint reader out of USB autosuspend"
cat > /etc/udev/rules.d/90-broadcom-fingerprint-power.rules << 'EOF'
# Override libfprint's autosuspend for Broadcom ControlVault 3 (0a5c:5843).
# /usr/lib/udev/rules.d/60-libfprint-2-device-broadcom.rules sets power/control=auto
# for this device. This rule (90-) runs after it and keeps the device on.
ACTION=="add|change", SUBSYSTEM=="usb", ATTRS{idVendor}=="0a5c", ATTRS{idProduct}=="5843", TEST=="power/control", ATTR{power/control}="on"
EOF
udevadm control --reload-rules
udevadm trigger --action=change --subsystem-match=usb --attr-match=idVendor=0a5c
udevadm settle
for d in /sys/bus/usb/devices/*; do
    if [[ "$(cat "$d/idVendor" 2>/dev/null)" == 0a5c && "$(cat "$d/idProduct" 2>/dev/null)" == 5843 ]]; then
        echo "    $d power/control = $(cat "$d/power/control")  (want: on)"
    fi
done

echo "==> [3/3] remove fprintd-resume.service if present"
if [[ -f /etc/systemd/system/fprintd-resume.service ]]; then
    systemctl disable fprintd-resume.service || true
    rm -f /etc/systemd/system/fprintd-resume.service
    systemctl daemon-reload
    echo "    removed"
else
    echo "    not installed, nothing to do"
fi

# Restart fprintd so no stale claim survives (it is D-Bus activated)
systemctl try-restart fprintd.service || true

echo
echo "Done. No reboot needed. Lock with SUPER+CTRL+L to test."
