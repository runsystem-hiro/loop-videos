#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/home/pi/loop-videos"
PLAYLIST="$BASE_DIR/videos/playlist.m3u"
LOG_FILE="$BASE_DIR/logs/mpv_drm.log"

mkdir -p "$BASE_DIR/logs"

# ---- Wait for ALSA analog (Headphones) to be ready (important for boot stability)
wait_alsa_headphones() {
  local timeout=15
  for i in $(seq 1 "$timeout"); do
    if aplay -l 2>/dev/null | grep -q "Headphones"; then
      return 0
    fi
    sleep 1
  done
  echo "WARN: ALSA Headphones not detected after ${timeout}s" | tee -a "$LOG_FILE"
  return 0
}

wait_alsa_headphones

while true; do
  "$BASE_DIR/scripts/build_playlist.sh" || true

  if [ ! -s "$PLAYLIST" ]; then
    echo "$(date) No videos in active/. Waiting..." | tee -a "$LOG_FILE"
    sleep 10
    continue
  fi

  echo "=== $(date) mpv start ===" | tee -a "$LOG_FILE"

  mpv --playlist="$PLAYLIST" \
    --vo=gpu \
    --gpu-context=drm \
    --hwdec=no \
    --fullscreen \
    --no-border \
    --keep-open=no \
    --loop-playlist=inf \
    --prefetch-playlist=yes \
    --cache=yes \
    --demuxer-readahead-secs=5 \
    --video-sync=display-resample \
    --framedrop=vo \
    --vd-lavc-threads=2 \
    --audio-device=alsa/plughw:CARD=Headphones,DEV=0 \
    --volume=100 \
    --mute=no \
    --no-osd-bar \
    --cursor-autohide=always \
    --msg-level=all=warn \
    --log-file="$LOG_FILE"

  echo "=== $(date) mpv exited (code=$?) -> restart in 2s ===" | tee -a "$LOG_FILE"
  sleep 2
done
