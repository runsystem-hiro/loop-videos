# 🎥 loop-videos — Raspberry Pi HDMI Digital Signage

**Raspberry Pi OS Bookworm Lite (64-bit) / DRM-KMS / mpv / 3.5mm Audio / systemd**

展示会向けに、Raspberry Pi 4B 上で **指定ディレクトリ内の MP4 を HDMI に全画面でループ再生**し、音声を **3.5mm（アナログ）** から出力するサイネージプレイヤーです。  
GUI（X11/Wayland）は使用せず、**DRM/KMS 直出し（tty1 専有）**で安定運用します。

---

## 1. ゴール / 設計方針

### ゴール

- 展示会での動画再生（長時間連続運用）
- 再起動後も自動再生
- 音声（3.5mm）を確実に出す
- 現場で「迷いなく復旧できる」

### 設計方針（重要）

- **Bookworm Lite 64-bit（CLI 運用）** を前提（GUI は使わない）
- 再生は `mpv` を **DRM/KMS 直出し**で実行（X11 不要）
- `tty1` は **サイネージ専用**として確保（`getty@tty1` を無効化・mask）
- 音声は **ALSA 直指定**で 3.5mm（Headphones）固定
- `systemd` 常駐 + 自己復旧（`mpv` 終了時も自動再開）
- ログ肥大化を防ぐ（`logrotate` + journald 上限推奨）

---

## 2. 仕様（要点）

- 再生対象: `/home/pi/loop-videos/videos/active/` 配下の `*.mp4`
- 再生順: **ファイル名昇順**
- ループ: 無限ループ
- 運用: 日程に応じて `active/` ⇔ `backup/` に移動して切替（結合不要）
- 出力: HDMI 全画面
- 音声: **3.5mm（アナログ）**
- 操作: SSH のみで運用可能（キーボード/マウス不要）

> 「ロゴを常時背面に表示」は DRM 直出しでは壁紙が使えないため、必要なら **動画へロゴ焼き込み**が最も安定します。

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

## 5. セットアップ（手順）

### 5.1 パッケージ導入

```bash
sudo apt update
sudo apt -y full-upgrade
sudo apt -y install mpv ffmpeg jq rsync
sudo reboot
```

### 5.2 HDMI を 1080p/60 に固定（推奨）

`/boot/firmware/config.txt` 末尾に追記（例）:

```txt
hdmi_force_hotplug=1
hdmi_group=1
hdmi_mode=16
hdmi_drive=1
dtparam=audio=on
gpu_mem=256
```

- `hdmi_drive=1` は DVI モード（HDMI 音声無効）  
  → 本構成は **3.5mm 音声固定**のため、競合を減らして安定します。

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

権限付与:

```bash
chmod +x /home/pi/loop-videos/scripts/*.sh
```

---

## 6. GPIO（オプション：物理シャットダウンボタン）

展示会で「物理ボタンで安全にシャットダウン」したい場合は `gpio-shutdown` を使います。  
（例: GPIO17 / active_low / pull-up）

`/boot/firmware/config.txt` に追記:

```txt
dtoverlay=gpio-shutdown,gpio_pin=17,active_low=1,gpio_pull=up
```

> GPIO 番号は **BCM 番号**です（GPIO17 = 物理ピン 11）。

---

## 7. systemd サービス（最重要：tty1 専有）

### 7.1 tty1 をサイネージ専用にする（getty 停止）

ログイン画面（getty）が tty1 を握ると、DRM/KMS 再生が不安定になることがあります。  
展示会運用では tty1 を **サイネージ専用**として確保するのが最も堅牢です。

```bash
sudo systemctl stop getty@tty1.service
sudo systemctl disable getty@tty1.service
sudo systemctl mask getty@tty1.service
```

### 7.2 `loop-videos.service` を作成（完全版）

以下を **そのまま** `/etc/systemd/system/loop-videos.service` として保存してください。

```ini
[Unit]
Description=Exhibition Signage Player (DRM/KMS mpv on tty1 - dedicated)
After=multi-user.target sound.target
Wants=sound.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/loop-videos

# tty1 を専有して DRM/KMS を安定させる（getty@tty1 を mask 済みが前提）
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes
StandardInput=tty
StandardOutput=journal
StandardError=journal

ExecStart=/home/pi/loop-videos/scripts/run_player_drm.sh

# 展示会用：落ちたら必ず復帰（スクリプト側も自己復旧ループ）
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
```

反映:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now loop-videos.service
sudo systemctl status loop-videos.service --no-pager
```

### 7.3 起動ターゲットを CLI へ（推奨）

```bash
sudo systemctl set-default multi-user.target
sudo reboot
```

> 重要: `openvt` は環境によって「console fd を取得できない」ため、本構成では採用しません。

---

## 8. logrotate（ログ肥大化対策）

### 8.1 mpv ログ

以下を **そのまま** `/etc/logrotate.d/loop-videos-mpv` として保存してください。

```conf
/home/pi/loop-videos/logs/mpv_drm.log {
    daily
    rotate 14
    size 20M
    missingok
    notifempty
    compress
    delaycompress
    copytruncate
    create 0644 pi pi
}
```

確認:

```bash
sudo logrotate -d /etc/logrotate.d/loop-videos-mpv
sudo logrotate -f /etc/logrotate.d/loop-videos-mpv
ls -la /home/pi/loop-videos/logs/
```

### 8.2 （推奨）journald の上限設定

`/etc/systemd/journald.conf` に例として:

```conf
SystemMaxUse=100M
SystemMaxFileSize=20M
MaxRetentionSec=7day
```

反映:

```bash
sudo systemctl restart systemd-journald
journalctl --disk-usage
```

---

## 9. 運用

### 9.1 動画の投入 / 切替

- 再生: `videos/active/` に置く
- 一時停止: `videos/backup/` に移す

反映:

```bash
sudo systemctl restart loop-videos.service
```

### 9.2 現場復旧（最短コマンド）

```bash
sudo systemctl restart loop-videos.service
sudo systemctl status loop-videos.service --no-pager
journalctl -u loop-videos.service -n 120 --no-pager
tail -n 120 /home/pi/loop-videos/logs/mpv_drm.log
```

### 9.3 動画転送（例）

Windows PowerShell:

```powershell
scp .\*.mp4 pi@<raspi-ip>:/home/pi/loop-videos/videos/active/
```

---

## 10. トラブルシュート（最小限）

### 再起動後に login 画面になる

- `getty@tty1` が mask されていない可能性があります。

```bash
systemctl status getty@tty1.service --no-pager
```

- `masked` になっていなければ 7.1 を再実行。

### 音が出ない（起動直後）

- `Headphones` が認識されているか:

```bash
aplay -l
```

- デバイス名が異なる場合は `run_player_drm.sh` の `--audio-device=` を修正。

### DRM 権限エラー

```bash
groups pi
ls -la /dev/dri
```

---

## 11. 復旧（元に戻す）

### tty1 のログイン画面を復活させる

```bash
sudo systemctl unmask getty@tty1.service
sudo systemctl enable --now getty@tty1.service
```

---

## 12. 運用上の推奨

- 本番中は `sudo apt upgrade` を実行しない（挙動差を避ける）
- 予備 microSD（複製）を準備すると現場復旧が高速
- 長期運用なら高耐久 microSD / SSD boot 推奨

---

## License

社内運用想定。必要に応じて `LICENSE` を追加してください（例: MIT）。
