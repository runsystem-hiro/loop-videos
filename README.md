# 🎥 loop-videos — Raspberry Pi HDMI Digital Signage

**Raspberry Pi OS Bookworm Lite (64-bit) / DRM-KMS / mpv / 3.5mm Audio / systemd**

展示会向けに、Raspberry Pi 4B 上で **指定ディレクトリ内の MP4 を HDMI に全画面でループ再生**し、音声を **3.5mm（アナログ）** から出力するサイネージプレイヤーです。  
GUI（X11/Wayland）は使用せず、**DRM/KMS 直出し（tty1 専有）**で安定運用します。

---

## 1. 目的と設計方針

### 目的

- 展示会での動画再生（長時間運用）
- 再起動後も自動で再生
- 音声（3.5mm）を確実に出す
- できるだけトラブル要因（GUI/VNC/セッション依存）を排除

### 設計方針（重要）

- **Bookworm Lite 64-bit**（CLI 運用）を前提
- 再生は `mpv` を **DRM/KMS 直出し**で実行（X11 不要）
- `tty1` は **サイネージ専用**として確保（getty を無効化・mask）
- 音声は **ALSA 直指定**で 3.5mm（Headphones）固定
- `systemd` 常駐 + 自己復旧（mpv 終了時も再開）
- ログは `logrotate` で肥大化を防止

---

## 2. 仕様（要点）

- 再生対象: `/home/pi/loop-videos/videos/active/` 配下の `*.mp4`
- 再生順: **ファイル名の昇順**
- ループ: 無限ループ
- 運用: 日程に応じて `active/` ⇔ `backup/` に移動して切替（結合不要）
- 出力: HDMI 全画面
- 音声: 3.5mm（アナログ）
- 操作: SSH のみで運用可能

---

## 3. 動作環境

- Raspberry Pi 4B（8GB 推奨）
- Raspberry Pi OS Bookworm Lite (64-bit)
- 動画: 1920×1080 / 30fps / MP4（H.264/AAC 想定）
- HDMI: 1080p/60 固定推奨
- 音声: 3.5mm（アナログ）

---

## 4. ディレクトリ構成

```bash
/home/pi/loop-videos/
  videos/
    active/        # 再生対象 mp4
    backup/        # 再生対象外（保管）
    playlist.m3u   # 自動生成（active の一覧）
  scripts/
    build_playlist.sh
    run_player_drm.sh
  logs/
    mpv_drm.log
```

---

## 5. セットアップ手順（最短）

### 5.1 パッケージ導入

```bash
sudo apt update
sudo apt -y full-upgrade
sudo apt -y install mpv ffmpeg jq rsync
sudo reboot
```

### 5.2 HDMI を 1080p/60 に固定（推奨）

`/boot/firmware/config.txt` 末尾に追記:

```txt
hdmi_force_hotplug=1
hdmi_group=1
hdmi_mode=16
hdmi_drive=1
dtparam=audio=on
gpu_mem=256
```

- `hdmi_drive=1` は DVI モード（HDMI 音声無効）  
  → 今回は 3.5mm 音声固定のため、競合を減らして安定します。

```bash
sudo reboot
```

### 5.3 DRM/KMS 権限（video グループ）

```bash
sudo usermod -aG video pi
sudo reboot
```

確認:

```bash
groups pi
ls -la /dev/dri
```

### 5.4 ディレクトリ作成

```bash
mkdir -p /home/pi/loop-videos/{videos/active,videos/backup,scripts,logs}
```

### 5.5 スクリプト配置

- `scripts/build_playlist.sh`（active から `playlist.m3u` を生成）
- `scripts/run_player_drm.sh`（DRM/KMS で再生。自己復旧ループ、音声デバイス待ちを含む）

> スクリプトの中身は本リポジトリの `scripts/` を参照してください。

権限付与:

```bash
chmod +x /home/pi/loop-videos/scripts/*.sh
```

---

## 6. systemd サービス（最重要：tty1 専有）

### 6.1 `tty1` をサイネージ専用にする（getty 停止）

ログイン画面（getty）が tty1 を握ると、DRM/KMS 再生が不安定になることがあります。  
展示会運用では tty1 を **サイネージ専用**として確保するのが最も堅牢です。

```bash
sudo systemctl stop getty@tty1.service
sudo systemctl disable getty@tty1.service
sudo systemctl mask getty@tty1.service
```

### 6.2 service 設定

`/etc/systemd/system/loop-videos.service` を配置します。  
ポイント:

- `TTYPath=/dev/tty1` で tty1 を掴む
- `Restart=always` で常駐運用
- `ExecStart=/home/pi/loop-videos/scripts/run_player_drm.sh`

反映:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now loop-videos.service
sudo systemctl status loop-videos.service --no-pager
```

### 6.3 起動ターゲットを CLI へ（推奨）

```bash
sudo systemctl set-default multi-user.target
sudo reboot
```

GUI へ戻す:

```bash
sudo systemctl set-default graphical.target
sudo reboot
```

> 重要: `openvt` は環境によって「console fd を取得できない」ため、本構成では採用しません。

---

## 7. logrotate（ログ肥大化対策）

`/etc/logrotate.d/loop-videos-mpv` を作成します。  
ポイント:

- `copytruncate` により mpv がログを掴んだままでも安全にローテート

適用・確認:

```bash
sudo logrotate -d /etc/logrotate.d/loop-videos-mpv
sudo logrotate -f /etc/logrotate.d/loop-videos-mpv
```

（推奨）journald 上限設定:

- `SystemMaxUse=100M`
- `MaxRetentionSec=7day`

---

## 8. 運用

### 8.1 動画の投入 / 切替

- 再生: `videos/active/` に置く
- 一時停止: `videos/backup/` に移す

反映:

```bash
sudo systemctl restart loop-videos.service
```

### 8.2 コマンド

```bash
sudo systemctl start loop-videos.service
sudo systemctl stop loop-videos.service
sudo systemctl restart loop-videos.service
sudo systemctl status loop-videos.service --no-pager
```

### 8.3 ログ確認

```bash
journalctl -u loop-videos.service -n 200 --no-pager
tail -n 200 /home/pi/loop-videos/logs/mpv_drm.log
```

---

## 9. トラブルシュート（要点）

### 再起動後に login 画面になる

- `getty@tty1` が生きている可能性があります。

```bash
systemctl status getty@tty1.service --no-pager
```

- 必要なら **mask** を再適用（上記 6.1）。

### 音が出ない（起動直後）

- `Headphones` が認識されているか確認:

```bash
aplay -l
```

- 音声デバイス名が異なる場合は `run_player_drm.sh` の `--audio-device=` を修正。

### DRM 権限エラー

```bash
groups pi
ls -la /dev/dri
```

---

## 10. 復旧（元に戻す方法）

### tty1 のログイン画面を復活させる

```bash
sudo systemctl unmask getty@tty1.service
sudo systemctl enable --now getty@tty1.service
```

---

## 11. 運用上の推奨

- 本番中は `apt upgrade` を避ける（挙動差を回避）
- 予備 microSD（複製）を準備すると現場復旧が高速
- 長期運用なら高耐久 microSD / SSD boot 推奨

---

## License

社内運用想定。必要に応じて `LICENSE` を追加してください（例: MIT）。

---

Powered by hiro
