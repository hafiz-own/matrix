#!/usr/bin/env bash
# Hyprlock Fingerprint Fix — System-level changes
# Run with:  sudo bash ~/.config/hypr/scripts/fix-fingerprint.sh

set -e

echo "==> [1/4] Cleaning /etc/pam.d/hyprlock ..."
cat > /etc/pam.d/hyprlock << 'EOF'
# PAM configuration file for hyprlock
# Native fingerprint is handled by hyprlock directly via D-Bus (fprintd).
# This stack handles password authentication only.
auth    include   login
EOF
echo "    done"

echo "==> [2/4] Creating udev rule to disable USB autosuspend for Broadcom ControlVault 3 ..."
cat > /etc/udev/rules.d/90-broadcom-fingerprint-power.rules << 'EOF'
# Override libfprint's autosuspend for Broadcom ControlVault 3 (0a5c:5843).
# /usr/lib/udev/rules.d/60-libfprint-2-device-broadcom.rules sets power/control=auto
# for this device. This rule (90-) runs after it and overrides to keep the device on.
ACTION=="add|change", SUBSYSTEM=="usb", ATTRS{idVendor}=="0a5c", ATTRS{idProduct}=="5843", TEST=="power/control", ATTR{power/control}="on"
EOF
echo "    done"

echo "==> [3/4] Applying udev rules immediately ..."
udevadm control --reload-rules
udevadm trigger --subsystem-match=usb --attr-match=idVendor=0a5c
POWER=$(cat /sys/bus/usb/devices/3-8/power/control 2>/dev/null || echo "unknown")
echo "    USB power/control is now: ${POWER}"
if [ "$POWER" = "on" ]; then
    echo "    Autosuspend disabled successfully"
else
    echo "    Still showing '${POWER}' - may need a reconnect to fully apply"
fi

echo "==> [4/4] Creating and enabling fprintd resume service ..."
cat > /etc/systemd/system/fprintd-resume.service << 'EOF'
[Unit]
Description=Restart fprintd after suspend/hibernate to clear stale device state
After=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target

[Service]
Type=oneshot
ExecStart=/usr/bin/systemctl restart fprintd.service

[Install]
WantedBy=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
EOF
systemctl daemon-reload
systemctl enable fprintd-resume.service
echo "    done"

echo ""
echo "== All system-level changes applied =="
echo ""
echo "  /etc/pam.d/hyprlock                              -> pam_fprintd.so removed"
echo "  /etc/udev/rules.d/90-broadcom-fingerprint-power.rules -> USB autosuspend disabled"
echo "  /etc/systemd/system/fprintd-resume.service       -> enabled"
echo ""
echo "No reboot required. Test now: hyprlock"
