# 🎞️ loop-videos

Raspberry Pi（64bit / CLI 環境）で、指定ディレクトリ内の `.mp4` 動画を **フルスクリーンかつ音声付きで連続再生**する軽量スクリプトです。

## ✅ 特徴

- GUI不要（Raspberry Pi OS Lite対応）
- HDMIに映像出力しつつ、音声は3.5mmジャックから出力
- VLC（`cvlc`）を使って超軽量ループ再生
- `systemd` または `.bashrc` などで自動起動可能

---

## 📁 ディレクトリ構成

```
loop-videos/
├── assets/              # 再生対象の動画ファイル (.mp4) を配置
│   ├── video1.mp4
│   └── video2.mp4
├── loop_videos.py       # メインの再生スクリプト
└── start_video.sh       # 起動用シェルスクリプト（省略可能）
```

---

## 🔧 セットアップ手順（Raspberry Pi）

### 1. 必要パッケージのインストール

```bash
sudo apt update
sudo apt install vlc -y
```

> `vlc` コマンドに含まれる `cvlc` を使用します。

---

### 2. スクリプトの実行確認（手動）

```bash
chmod +x start_video.sh
./start_video.sh
```

または直接：

```bash
python3 loop_videos.py
```

---

### 3. 自動起動させたい場合（例：.bashrc）

```bash
nano ~/.bashrc
```

末尾に以下を追記：

```bash
/home/pi/loop-videos/start_video.sh &
```

> HDMIディスプレイが接続されており、かつ**自動ログイン**が有効な場合に動作します。

---

## 🔁 動作仕様【loop_videos.py】

- `/home/pi/loop-videos/assets/` 内の `.mp4` ファイルを昇順ソートして取得
- `cvlc` に渡して全画面・静音・音声は `alsa`（3.5mmジャック）で出力
- `--loop` オプションで動画を順に再生し、最後まで行ったら最初に戻る

ソースハイライト：

```python
VLC_COMMAND = [
    "cvlc",
    "--fullscreen",
    "--no-video-title-show",
    "--video-on-top",
    "--playlist-autostart",
    "--loop",
    "--quiet",
    "--aout", "alsa"
] + video_files
```

---

## 📦 応用的な使い方（例）

- 縦長動画をあらかじめ FFMPEG で 1920x1080 化（ぼかし背景付き）
- `systemd` を使ってサービスとして管理
- 音声を HDMI 出力にしたい場合は `--aout alsa` を省略 or `--aout hdmi`

---

## 📜 ライセンス

MIT License
商用施設・展示・案内システムでの使用にも適します。

---

## 👤 作者

[ヒロ | hirotech]
