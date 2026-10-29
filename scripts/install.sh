#!/usr/bin/env bash
set -euo pipefail

TARGET_USER="pi"
BASE_DIR="/home/${TARGET_USER}/loop-videos"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="$(dirname "$SCRIPT_DIR")"
UNIT_SOURCE="$SOURCE_ROOT/systemd/loop-videos.service"
UNIT_TARGET="/etc/systemd/system/loop-videos.service"
CONFIG_SOURCE="$SOURCE_ROOT/config/loop-videos.env"
CONFIG_TARGET="/etc/default/loop-videos"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

require_root() {
  [ "$(id -u)" -eq 0 ] || fail "Run with sudo: sudo ./scripts/install.sh"
}

require_file() {
  [ -f "$1" ] || fail "Required file not found: $1"
}

require_root
require_file "$SCRIPT_DIR/build_playlist.sh"
require_file "$SCRIPT_DIR/run_player_drm.sh"
require_file "$UNIT_SOURCE"
require_file "$CONFIG_SOURCE"
id "$TARGET_USER" >/dev/null 2>&1 || fail "User '${TARGET_USER}' does not exist"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y mpv alsa-utils

test -c /dev/dri/card0 || fail "/dev/dri/card0 was not found; DRM/KMS is unavailable"
aplay -l 2>/dev/null | grep -Fq "Headphones" || fail "ALSA card 'Headphones' was not found"
mpv --hwdec=help 2>&1 | grep -Fq "v4l2m2m" || fail "mpv does not provide V4L2 M2M decoding"

install -d -o "$TARGET_USER" -g "$TARGET_USER" -m 0755 \
  "$BASE_DIR" \
  "$BASE_DIR/scripts" \
  "$BASE_DIR/videos/active" \
  "$BASE_DIR/videos/backup" \
  "$BASE_DIR/logs"

if [ "$SCRIPT_DIR" != "$BASE_DIR/scripts" ]; then
  install -o "$TARGET_USER" -g "$TARGET_USER" -m 0755 \
    "$SCRIPT_DIR/build_playlist.sh" "$BASE_DIR/scripts/build_playlist.sh"
  install -o "$TARGET_USER" -g "$TARGET_USER" -m 0755 \
    "$SCRIPT_DIR/run_player_drm.sh" "$BASE_DIR/scripts/run_player_drm.sh"
else
  chmod 0755 "$BASE_DIR/scripts/build_playlist.sh" "$BASE_DIR/scripts/run_player_drm.sh"
  chown "$TARGET_USER:$TARGET_USER" "$BASE_DIR/scripts/build_playlist.sh" "$BASE_DIR/scripts/run_player_drm.sh"
fi

usermod -aG video "$TARGET_USER"
install -o root -g root -m 0644 "$UNIT_SOURCE" "$UNIT_TARGET"
if [ ! -f "$CONFIG_TARGET" ]; then
  install -D -o root -g root -m 0644 "$CONFIG_SOURCE" "$CONFIG_TARGET"
fi

systemctl daemon-reload
systemctl stop getty@tty1.service 2>/dev/null || true
systemctl disable getty@tty1.service 2>/dev/null || true
systemctl mask getty@tty1.service
systemctl enable --now loop-videos.service
sleep 2
systemctl is-active --quiet loop-videos.service || fail "loop-videos.service did not start"

echo "OK: loop-videos.service is active"
echo "OK: place MP4 files in $BASE_DIR/videos/active/"
echo "OK: verify with: systemctl status loop-videos.service --no-pager"
