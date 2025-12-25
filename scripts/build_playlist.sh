#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/home/pi/loop-videos"
ACTIVE_DIR="$BASE_DIR/videos/active"
PLAYLIST="$BASE_DIR/videos/playlist.m3u"

mkdir -p "$ACTIVE_DIR"
rm -f "$PLAYLIST"

find "$ACTIVE_DIR" -maxdepth 1 -type f -name "*.mp4" | sort > "$PLAYLIST"

if [ ! -s "$PLAYLIST" ]; then
  echo "WARN: No mp4 found in $ACTIVE_DIR"
  exit 0
fi

echo "OK: playlist updated: $PLAYLIST"
