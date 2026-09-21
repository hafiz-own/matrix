#!/usr/bin/env bash
set -euo pipefail

USER_NAME="$(whoami)"
GROUP_NAME="$(id -gn)"
SERVICE_DIR="$HOME/.config/systemd/user"

echo "==> Checking dependencies..."
for cmd in rclone fusermount3 sudo; do
    command -v "$cmd" >/dev/null || {
        echo "Error: '$cmd' is not installed."
        exit 1
    }
done

echo "==> Checking rclone remotes..."
for remote in gdrive gdrive_ho27 mega; do
    rclone listremotes | grep -qx "${remote}:" || {
        echo "Error: rclone remote '${remote}:' not found."
        echo "Run: rclone config"
        exit 1
    }
done

echo "==> Creating mount points in /home/..."
sudo install -d -o "$USER_NAME" -g "$GROUP_NAME" /home/gdrive
sudo install -d -o "$USER_NAME" -g "$GROUP_NAME" /home/gdrive_ho27
sudo install -d -o "$USER_NAME" -g "$GROUP_NAME" /home/mega

echo "==> Creating user directories..."
mkdir -p \
    "$HOME/.cache/rclone/gdrive" \
    "$HOME/.cache/rclone/gdrive_ho27" \
    "$HOME/.cache/rclone/mega" \
    "$SERVICE_DIR"

echo "==> Creating Google Drive service..."
cat > "$SERVICE_DIR/rclone-gdrive.service" <<'EOF'
[Unit]
Description=Rclone Google Drive Mount
After=default.target

[Service]
Type=notify
ExecStartPre=-/usr/bin/fusermount3 -uz /home/gdrive
ExecStart=/usr/bin/rclone mount gdrive: /home/gdrive \
  --vfs-cache-mode full \
  --vfs-cache-max-size 20G \
  --vfs-cache-max-age 24h \
  --vfs-write-back 30s \
  --buffer-size 32M \
  --vfs-read-chunk-size 128M \
  --vfs-read-chunk-size-limit 2G \
  --dir-cache-time 1000h \
  --poll-interval 1m \
  --attr-timeout 1s \
  --vfs-fast-fingerprint \
  --drive-chunk-size 32M \
  --tpslimit 10 \
  --tpslimit-burst 20 \
  --transfers 4 \
  --checkers 8 \
  --cache-dir %h/.cache/rclone/gdrive
ExecStop=/usr/bin/fusermount3 -uz /home/gdrive
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

echo "==> Creating second Google Drive service..."
cat > "$SERVICE_DIR/rclone-gdrive-ho27.service" <<'EOF'
[Unit]
Description=Rclone Google Drive HO27 Mount
After=default.target

[Service]
Type=notify
ExecStartPre=-/usr/bin/fusermount3 -uz /home/gdrive_ho27
ExecStart=/usr/bin/rclone mount gdrive_ho27: /home/gdrive_ho27 \
  --vfs-cache-mode full \
  --vfs-cache-max-size 20G \
  --vfs-cache-max-age 24h \
  --vfs-write-back 30s \
  --buffer-size 32M \
  --vfs-read-chunk-size 128M \
  --vfs-read-chunk-size-limit 2G \
  --dir-cache-time 1000h \
  --poll-interval 1m \
  --attr-timeout 1s \
  --vfs-fast-fingerprint \
  --drive-chunk-size 32M \
  --tpslimit 10 \
  --tpslimit-burst 20 \
  --transfers 4 \
  --checkers 8 \
  --cache-dir %h/.cache/rclone/gdrive_ho27
ExecStop=/usr/bin/fusermount3 -uz /home/gdrive_ho27
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

echo "==> Creating MEGA service..."
cat > "$SERVICE_DIR/rclone-mega.service" <<'EOF'
[Unit]
Description=Rclone MEGA Mount
After=default.target

[Service]
Type=notify
ExecStartPre=-/usr/bin/fusermount3 -uz /home/mega
ExecStart=/usr/bin/rclone mount mega: /home/mega \
  --vfs-cache-mode full \
  --vfs-cache-max-size 20G \
  --vfs-cache-max-age 24h \
  --vfs-write-back 30s \
  --buffer-size 32M \
  --vfs-read-chunk-size 128M \
  --vfs-read-chunk-size-limit 2G \
  --dir-cache-time 15m \
  --attr-timeout 1s \
  --vfs-fast-fingerprint \
  --tpslimit 10 \
  --tpslimit-burst 20 \
  --transfers 4 \
  --checkers 8 \
  --cache-dir %h/.cache/rclone/mega
ExecStop=/usr/bin/fusermount3 -uz /home/mega
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

echo "==> Enabling lingering so mounts start on boot without interactive login..."
loginctl enable-linger "$USER_NAME"

echo "==> Reloading systemd..."
systemctl --user daemon-reload

echo "==> Enabling and starting services..."
systemctl --user enable --now rclone-gdrive.service
systemctl --user enable --now rclone-gdrive-ho27.service
systemctl --user enable --now rclone-mega.service

echo
echo "==> Mounts configured at:"
echo "    /home/gdrive       -> gdrive:"
echo "    /home/gdrive_ho27  -> gdrive_ho27:"
echo "    /home/mega         -> mega:"
echo
echo "==> Services:"
systemctl --user --no-pager status rclone-gdrive.service || true
systemctl --user --no-pager status rclone-gdrive-ho27.service || true
systemctl --user --no-pager status rclone-mega.service || true
