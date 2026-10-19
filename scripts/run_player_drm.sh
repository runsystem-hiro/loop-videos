#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/home/pi/loop-videos"
PLAYLIST="$BASE_DIR/videos/playlist.m3u"
LOG_FILE="$BASE_DIR/logs/mpv_drm.log"
# Raspberry Pi OS Bookworm / Trixie の標準オンボード 3.5mm 出力。
# 個体でカード名が異なる場合は systemd の Environment= で上書きする。
AUDIO_DEVICE="${AUDIO_DEVICE:-alsa/plughw:CARD=Headphones,DEV=0}"
ALSA_CARD_NAME="${ALSA_CARD_NAME:-Headphones}"
ALSA_WAIT_SECONDS="${ALSA_WAIT_SECONDS:-30}"

mkdir -p "$BASE_DIR/logs"

# ---- Wait for ALSA analog (Headphones) to be ready (important for boot stability)
wait_alsa_headphones() {
  local timeout="$ALSA_WAIT_SECONDS"
  for i in $(seq 1 "$timeout"); do
    if aplay -l 2>/dev/null | grep -Fq "$ALSA_CARD_NAME"; then
      return 0
    fi
    sleep 1
  done
  echo "WARN: ALSA card '${ALSA_CARD_NAME}' was not detected after ${timeout}s; mpv will be retried" | tee -a "$LOG_FILE"
  return 0
}

while true; do
  wait_alsa_headphones
  "$BASE_DIR/scripts/build_playlist.sh" || true

  if [ ! -s "$PLAYLIST" ]; then
    echo "$(date) No videos in active/. Waiting..." | tee -a "$LOG_FILE"
    sleep 10
    continue
  fi

  echo "=== $(date) mpv start ===" | tee -a "$LOG_FILE"

  # mpv の終了コードを明示的に受ける。set -e のままでは異常終了時に
  # この自己復旧ループも終了してしまうため、systemd 依存だけにしない。
  set +e
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
    --audio-device="$AUDIO_DEVICE" \
    --volume=100 \
    --mute=no \
    --no-osd-bar \
    --cursor-autohide=always \
    --msg-level=all=warn \
    --log-file="$LOG_FILE"
  mpv_status=$?
  set -e

  echo "=== $(date) mpv exited (code=${mpv_status}) -> restart in 2s ===" | tee -a "$LOG_FILE"
  sleep 2
done
