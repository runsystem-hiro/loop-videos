#!/usr/bin/env python3
"""
loop_videos.py – Raspberry Pi OS (Bookworm/Bullseye)
"""

from __future__ import annotations
import glob
import logging
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Final

ENV_FILE: Final = Path(__file__).with_name(".env")

def load_env(path: Path) -> dict[str, str]:
    if not path.exists():
        sys.exit(f".env not found: {path}")
    env: dict[str, str] = {}
    for line in path.read_text().splitlines():
        if not line or line.lstrip().startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        env[k.strip()] = v.strip()
    return env

cfg = load_env(ENV_FILE)

VIDEO_DIR          = Path(cfg.get("VIDEO_DIR", "/home/pi/loop-videos/assets"))
SUPPORTED_FORMATS  = [p.strip() for p in cfg.get("SUPPORTED_FORMATS", "*.mp4").split(",")]
PLAYER             = cfg.get("PLAYER", "mpv")
PLAYER_OPTIONS     = cfg.get("PLAYER_OPTIONS", "--fs --loop-playlist --really-quiet").split()
LOGIN_WAIT_TIME    = int(cfg.get("LOGIN_WAIT_TIME", "1"))
LOG_LEVEL          = cfg.get("LOG_LEVEL", "INFO").upper()

logging.basicConfig(
    level=getattr(logging, LOG_LEVEL, logging.INFO),
    format="%(asctime)s %(levelname)s: %(message)s"
)

def collect_videos() -> list[str]:
    files: list[str] = []
    for pattern in SUPPORTED_FORMATS:
        files.extend(glob.glob(str(VIDEO_DIR / pattern)))
    return sorted(files)

def countdown(sec: int) -> None:
    for i in range(sec, 0, -1):
        print(f"Starting in {i}…", end="\r", flush=True)
        time.sleep(1)
    print(" " * 20, end="\r")

def main() -> None:
    logging.info("Digital Signage Player starting (backend: %s)", PLAYER)
    videos = collect_videos()
    if not videos:
        logging.error("No video files found in %s", VIDEO_DIR)
        sys.exit(1)

    countdown(LOGIN_WAIT_TIME)

    cmd = [PLAYER, *PLAYER_OPTIONS, *videos]
    logging.info("Exec: %s", " ".join(cmd))
    subprocess.run(cmd, check=False)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        logging.info("Interrupted by user")
