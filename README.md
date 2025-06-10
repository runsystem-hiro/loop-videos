# 🖥️ Raspberry Pi デジタルサイネージ

Raspberry Pi 4B (64‑bit **Bookworm/Bullseye**) を HDMI 出力専用サイネージ端末として運用する最小構成です。動画ファイルをフォルダに置いて再起動するだけで無限ループ再生します。

| 項目             | 採用技術                                         |
| -------------- | -------------------------------------------- |
| 🎬 **プレーヤー**   | `mpv`（DRM PRIME HW デコード・自動アスペクト保持）           |
| 🐍 **制御スクリプト** | `loop_videos.py`（Python 3 標準モジュールのみ）         |
| ⚙️ **設定**      | `.env` 1 ファイルに統一                             |
| 🔄 **自動起動**    | `systemd` サービス `loopplayer.service`（tty1 専有） |

---

## 🎯 tty1 を占有するメリット

Raspberry Pi のコンソール (tty1) を **専用でプレーヤーに割り当てる** ことで、デジタルサイネージとして次の利点が得られます。

* **不要な文字列を完全排除**：login プロンプトやカーネルメッセージが映像に重ならない。
* **シームレスなブート体験**：電源投入後すぐに動画が表示され、黒→文字→映像のチラつきがない。
* **誤操作に強い**：ESC や Ctrl‑C が tty1 以外へ届かず、現場での不意の停止を防止。
* **スクリーンセーバ無効**：`setterm` を ExecStartPre で実行し DPMS / カーソル / ブランクを無効化。
* **単一インスタンス保証**：systemd が tty1 で 1 プロセスを管理し、多重起動やゾンビを防ぐ。
* **保守性向上**：`journalctl -u loopplayer` でログ一元化、`sudo systemctl` だけで再起動・停止が可能。


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

| 目的             | コマンド                                          |
| -------------- | --------------------------------------------- |
| 🔄 **サービス再起動** | `sudo systemctl restart loopplayer`           |
| ⏹️ **サービス停止**  | `sudo systemctl stop loopplayer`              |
| ▶️ **サービス開始**  | `sudo systemctl start loopplayer`             |
| 🔍 **状態確認**    | `sudo systemctl status loopplayer --no-pager` |
| 📜 **直近ログ**    | `journalctl -u loopplayer -n 50 --no-pager`   |

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

| 症状                 | 対処                                                |
| ------------------ | ------------------------------------------------- |
| 🖤 **黒画面・音声のみ**    | `/boot/config.txt` に `gpu_mem=256` を追加し再起動        |
| 🔄 **login 文字が被る** | `sudo systemctl disable --now getty@tty1.service` |
| 🔉 **PipeWire 警告** | 無害。消す場合 `PLAYER_OPTIONS+=--ao=alsa`               |

---

## 📜 8. ライセンス

MIT License © 2025 Hiro (runsystem)

---
