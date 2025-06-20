#!/usr/bin/env python3
import os
import subprocess
import glob
import sys

# 動画ディレクトリの絶対パス
VIDEO_DIR = "/home/pi/loop-videos/assets"

# .mp4 ファイルを取得（ソート付きで順序保証）
video_files = sorted(glob.glob(os.path.join(VIDEO_DIR, "*.mp4")))

# ファイルが存在しない場合は終了
if not video_files:
    print("⚠ No video files found in:", VIDEO_DIR)
    sys.exit(1)

# VLC のオプション
VLC_COMMAND = [
    "cvlc",
    "--fullscreen",                # 全画面再生
    "--no-video-title-show",       # タイトル非表示
    "--video-on-top",              # 他ウィンドウより前面に表示
    "--playlist-autostart",        # プレイリスト自動開始
    "--loop",           # 最後の動画再生後、最初に戻ってループ
    "--quiet",                     # コンソール出力を抑制
    "--aout", "alsa"               # 音声出力をALSA（3.5mmジャック）
] + video_files                    # 動画ファイル群を引数として渡す

# VLC を実行（終了しない限りループ再生）
try:
    subprocess.run(VLC_COMMAND)
except Exception as e:
    print("❌ Playback error:", e)
    sys.exit(1)
