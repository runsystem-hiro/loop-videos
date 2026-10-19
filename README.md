# 🎥 loop-videos — Raspberry Pi HDMI Digital Signage

## 対応環境

Raspberry Pi OS Bookworm / Trixie Lite (64-bit) / DRM-KMS / mpv / 3.5mm Audio / systemd

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

- **Bookworm Lite または Trixie Lite 64-bit（CLI 運用）** を前提（GUI は使わない）
- 再生は `mpv` を **DRM/KMS 直出し**で実行（X11 不要）
- `tty1` は **サイネージ専用**として確保（`getty@tty1` を無効化・mask）
- 音声は **ALSA 直指定**で 3.5mm（Headphones）固定
- H.264/HEVC は **V4L2 M2M ハードウェアデコード**を使用（Pi 4Bの1080p再生を安定化）
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

---

## 3. 動作環境

- Raspberry Pi 4B（8GB 推奨）
- Raspberry Pi OS Bookworm Lite (64-bit) または Trixie Lite (64-bit)
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

Bookworm と Trixie のどちらでも同じ手順です。Trixie は Debian 13 系で、
`mpv` 0.40 系を含みます。本構成は PipeWire/PulseAudio を経由せず、mpv から
ALSA のオンボード Headphones デバイスへ直接出力するため、Lite 環境でも GUI は不要です。

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
- Trixie では `auto_initramfs` が標準で有効です。既存の設定を削除・置換せず、
  上記の必要な行だけを追記してください。

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

Trixie で初回起動後に、DRM/KMS とオンボード音声を必ず確認します。

```bash
test -c /dev/dri/card0 && echo 'OK: DRM card0'
aplay -l
mpv --version
```

正常時は `/dev/dri/card0` が存在し、`aplay -l` に `Headphones` を含むカードが表示されます。
カード名が異なる場合は、後述の「音が出ない」の手順で service の `AUDIO_DEVICE` と
`ALSA_CARD_NAME` を実機の値へ変更してください。

TrixieではH.264/HEVC用の `v4l2m2m` が表示されることも確認します。

```bash
mpv --hwdec=help | grep -F v4l2m2m
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

# 任意: aplay -l で Headphones 以外のカード名だった場合だけ指定する
# Environment="ALSA_CARD_NAME=Headphones"
# Environment="AUDIO_DEVICE=alsa/plughw:CARD=Headphones,DEV=0"
# 任意: 動画互換性の調査時のみソフトウェアデコードへ切り替える
# Environment="MPV_HWDEC=no"

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
- 非再生: `videos/backup/` に移す

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
- **Trixie を含め、スクリプト本体を直接編集する必要はありません。**
  `aplay -l` に表示された実際のカード名へ、`loop-videos.service` の
  `Environment` 2行を設定してから反映します（例は USB 音声ではなくオンボード名が
  異なる場合）。

```ini
Environment="ALSA_CARD_NAME=<aplay -l に表示されたカード名>"
Environment="AUDIO_DEVICE=alsa/plughw:CARD=<同じカード名>,DEV=0"
```

```bash
sudo systemctl daemon-reload
sudo systemctl restart loop-videos.service
journalctl -u loop-videos.service -n 120 --no-pager
```

### Trixie Lite 初回導入時の確認

以下は、Trixie Lite 64-bit の初回導入後に実行する受入確認です。すべて `OK` または
`active (running)` になれば、Bookworm と同じ運用手順へ移行できます。

```bash
cat /etc/os-release
test -c /dev/dri/card0 && echo 'OK: DRM/KMS'
aplay -l | grep -F Headphones && echo 'OK: analog audio'
systemctl is-enabled getty@tty1.service
systemctl is-active loop-videos.service
journalctl -b -u loop-videos.service --no-pager -n 120
```

- `getty@tty1.service` は `masked` が正常です。
- サービスログに `mpv start` があり、画面・3.5mm 音声が再生されれば受入完了です。

### 映像がカクつく

Pi 4Bで1080p動画をソフトウェアデコードするとCPU使用率が飽和し、カクつく場合があります。
本スクリプトは既定で `--hwdec=v4l2m2m-copy` を使用します。ログで実際にハードウェア
デコードが有効になったことを確認してください。

```bash
tail -n 200 /home/pi/loop-videos/logs/mpv_drm.log | grep -E 'hwdec=|Using hardware decoding'
```

原因切り分けのため一時的にソフトウェアデコードへ戻す場合だけ、serviceに次を追加して
再起動します。

```ini
Environment="MPV_HWDEC=no"
```

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

社内運用想定

© hiro MIT License
