# 🖥️ Raspberry Pi デジタルサイネージ

Raspberry Pi 4B (64‑bit **Bookworm/Bullseye**) を HDMI 出力専用サイネージ端末として運用する最小構成です。動画ファイルをフォルダに置いて再起動するだけで無限ループ再生します。

| 項目                  | 採用技術                                             |
| --------------------- | ---------------------------------------------------- |
| 🎬 **プレーヤー**     | `mpv`（DRM PRIME HW デコード・自動アスペクト保持）   |
| 🐍 **制御スクリプト** | `loop_videos.py`（Python 3 標準モジュールのみ）      |
| ⚙️ **設定**           | `.env` 1 ファイルに統一                              |
| 🔄 **自動起動**       | `systemd` サービス `loopplayer.service`（tty1 専有） |

## 🎯 tty1 を占有するメリット

Raspberry Pi のコンソール (tty1) を **専用でプレーヤーに割り当てる** ことで、デジタルサイネージとして次の利点が得られます。

- **不要な文字列を完全排除**：login プロンプトやカーネルメッセージが映像に重ならない。
- **シームレスなブート体験**：電源投入後すぐに動画が表示され、黒 → 文字 → 映像のチラつきがない。
- **誤操作に強い**：ESC や Ctrl‑C が tty1 以外へ届かず、現場での不意の停止を防止。
- **スクリーンセーバ無効**：`setterm` を ExecStartPre で実行し DPMS / カーソル / ブランクを無効化。
- **単一インスタンス保証**：systemd が tty1 で 1  プロセスを管理し、多重起動やゾンビを防ぐ。
- **保守性向上**：`journalctl -u loopplayer` でログ一元化、`sudo systemctl` だけで再起動・停止が可能。

---

## 📦 1. 依存パッケージ

```bash
sudo apt update
sudo apt install -y mpv python3   # 追加ライブラリ不要
```

---

## 📂 2. ディレクトリ構成（例）

```text
/home/pi/loop-videos/
├── loop_videos.py        # スクリプト本体
├── .env                  # 設定ファイル（下記テンプレ参照）
├── loopplayer.service    # systemd ユニット
└── assets/               # 再生ファイル格納
    ├── 01_movie1.mp4
    ├── 02_vertical_ad.mp4
    └── 03_promo.mp4
```

---

## ⏩ 3. 再生順ルール

1. `SUPPORTED_FORMATS` に合致するファイルを **辞書順ソート** で取得。
2. `--loop-playlist` で無限ループ再生。
3. **桁数を揃えた数字プレフィクス**（例 `01_`〜`99_`）を付けると順序が固定。

> フォルダ更新後は `sudo systemctl restart loopplayer` で即反映！

---

## ⚙️ 4. `.env` テンプレート

```dotenv
VIDEO_DIR=/home/pi/loop-videos/assets
SUPPORTED_FORMATS=*.mp4,*.mov

PLAYER=mpv
PLAYER_OPTIONS=--fs --loop-playlist --no-border --really-quiet --ao=alsa

LOGIN_WAIT_TIME=1   # 起動前カウントダウン秒
LOG_LEVEL=INFO
```

---

## 🛠️ 5. よく使う運用コマンド

| 目的                  | コマンド                                      |
| --------------------- | --------------------------------------------- |
| 🔄 **サービス再起動** | `sudo systemctl restart loopplayer`           |
| ⏹️ **サービス停止**   | `sudo systemctl stop loopplayer`              |
| ▶️ **サービス開始**   | `sudo systemctl start loopplayer`             |
| 🔍 **状態確認**       | `sudo systemctl status loopplayer --no-pager` |
| 📜 **直近ログ**       | `journalctl -u loopplayer -n 50 --no-pager`   |

---

## 🚀 6. 初回セットアップ手順

```bash
# 1) コード配置
mkdir -p /home/pi/loop-videos && cd /home/pi/loop-videos
git clone <repo> .

# 2) systemd サービス登録
sudo cp loopplayer.service /etc/systemd/system/
sudo systemctl daemon-reload

# 3) tty1 を専有（1回だけ）
sudo systemctl disable --now getty@tty1.service

# 4) 自動起動
sudo systemctl enable --now loopplayer.service
```

---

## 🚑 7. トラブルシューティング

| 症状                    | 対処                                               |
| ----------------------- | -------------------------------------------------- |
| 🖤 **黒画面・音声のみ** | `/boot/config.txt` に `gpu_mem=256` を追加し再起動 |
| 🔄 **login 文字が被る** | `sudo systemctl disable --now getty@tty1.service`  |
| 🔉 **PipeWire 警告**    | 無害。消す場合 `PLAYER_OPTIONS+=--ao=alsa`         |

## 例：最小実用セット

```bash
#/boot/firmware/config.txt

arm_64bit=1
disable_overscan=1
dtoverlay=vc4-kms-v3d
gpu_mem=512
cma=320M
hdmi_force_hotplug=1
hdmi_group=1
hdmi_mode=16
audio_output=1

# ==== physical shutdown button ====
dtoverlay=gpio-shutdown,gpio_pin=17,active_low=1,gpio_pull=up
```

```bash
#/boot/firmware/cmdline.txt
....... rootwait cma=320M cfg ...
```

---

# 🛠️ 8. loop_videos.py 管理・メンテナンス用コマンド集

```bash
# ---------------------------------------------
# 🔁 サービス制御（systemd）
# ---------------------------------------------

# サービスの停止
sudo systemctl stop loopplayer

# サービスの開始
sudo systemctl start loopplayer

# サービスの再起動
sudo systemctl restart loopplayer

# サービスの状態確認
sudo systemctl status loopplayer --no-pager

# サービスの自動起動を有効化
sudo systemctl enable loopplayer

# サービスの自動起動を無効化
sudo systemctl disable loopplayer

# tty1の占有（login抑止）
sudo systemctl disable --now getty@tty1.service


# ---------------------------------------------
# 📜 ログの確認（journalctl）
# ---------------------------------------------

# 直近50件のログを表示
journalctl -u loopplayer -n 50 --no-pager

# リアルタイムログを監視
journalctl -u loopplayer -f

# 指定時間以降のログを表示
journalctl -u loopplayer --since "2025-06-17 10:00"


# ---------------------------------------------
# 🎥 mpvログの確認（--log-file指定時）
# ---------------------------------------------

# mpvログの中身を表示
cat /run/mpv.log

# mpvログを追跡表示（リアルタイム）
tail -f /run/mpv.log

# mpvログを削除（不要時）
sudo rm /run/mpv.log


# ---------------------------------------------
# 🧠 メモリ・CPU使用状況の確認
# ---------------------------------------------

# メモリ使用状況の概要
free -h

# スワップやIOを含む動的状況（1秒ごと更新）
vmstat 1

# プロセス監視
top

# メモリ使用率が高いプロセスを表示（上位10件）
ps -eo pid,comm,%mem --sort=-%mem | head



# ---------------------------------------------
# ⚙️ Overlay Filesystem 関連
# ---------------------------------------------

# raspi-configを起動してOverlay FSを有効/無効に設定
sudo raspi-config
# → Performance Options → Overlay Filesystem

# 現在のマウント状態を確認
mount | grep overlay

# 再起動
sudo reboot
```

---

## 📜 9. ライセンス

MIT License © 2025 hiro (runsystem)

---
