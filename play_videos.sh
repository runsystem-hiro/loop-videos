#!/bin/bash

VIDEO_DIR="/home/pi/loop-videos/assets"
MPV_OPTIONS="--fs --no-terminal --really-quiet --audio-device=alsa/plughw:0,0"

# ファイル名順に動画を無限ループ再生
while true; do
  for video in "$VIDEO_DIR"/*.mp4; do
    if [ -f "$video" ]; then
      mpv $MPV_OPTIONS "$video"
    fi
  done
done
