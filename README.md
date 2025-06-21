
# 🎥 loop-videos — Raspberry Pi HDMI Digital Signage

Raspberry Pi 4B (8GB) 向けのシンプルで信頼性の高い動画サイネージシステムです。  
電源を入れるだけで、HDMIモニタに `.mp4` 動画をフルスクリーン＆音声付きで順番にループ再生します。  
SSHでの運用に最適化されており、GUIは不要です。

---

## 🎯 構成

- Raspberry Pi OS Bookworm 64bit (CLI 専用)
- mpv による軽量なフルHD動画再生
- 3.5mm ジャックから音声出力
- 起動時自動再生（`systemd` 管理）
- GPIO シャットダウンボタン対応

---

## 📂 ディレクトリ構成

```bash
/home/pi/loop-videos/
├── assets/             # 動画ファイル (.mp4) を格納するフォルダ
└── play_videos.sh      # 再生ループスクリプト
```

---

## 📦 依存パッケージ

```bash
sudo apt update
sudo apt install -y mpv
```

## 🚀 初回セットアップ手順

```bash
# 1) コード配置
mkdir -p /home/pi/loop-videos && cd /home/pi/loop-videos
git clone <repo> .

# 2) systemd サービス登録
sudo cp loop-videos.service /etc/systemd/system/
sudo systemctl daemon-reexec
sudo systemctl daemon-reload

# 3) 自動起動
sudo systemctl enable loop-videos.service
sudo systemctl start loop-videos.service
```

---

## 🛠️ config.txt の設定例

```ini
[all]
hdmi_force_hotplug=1
hdmi_group=1
hdmi_mode=16
config_hdmi_boost=7
hdmi_drive=1
audio=on
gpu_mem=128

# ==== physical shutdown button ====
dtoverlay=gpio-shutdown,gpio_pin=17,active_low=1,gpio_pull=up
```

---

## 🔄 操作コマンド（SSHから）

| 動作        | コマンド |
|-------------|----------|
| 再生開始    | `sudo systemctl start loop-videos.service` |
| 再生停止    | `sudo systemctl stop loop-videos.service`  |
| ステータス確認 | `systemctl status loop-videos.service`      |

---

## 🧪 テスト

1. `/home/pi/loop-videos/assets/` に `.mp4` を数本配置
2. `sudo reboot` 後に自動再生されるか確認
3. 音声が 3.5mm ジャックから出力されているか確認

---

## 🔌 シャットダウンボタン（GPIO17）

- **物理ピン 11（GPIO17）と GND（例：ピン6）** をボタンで接続
- 押すと `sudo shutdown -h now` が安全に実行されます

---

## 📝 ライセンス

MIT License 商用施設・展示・案内システムでの使用にも適します

---

Powered by hiro

