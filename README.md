# loop-videos

Raspberry Pi 4Bで、指定ディレクトリのMP4をHDMIへ全画面・無限ループ再生する展示用プレイヤーです。
GUIは使わず、DRM/KMS・mpv・systemdで動作します。音声は3.5mmアナログ出力です。

## 対応環境

- Raspberry Pi 4B
- Raspberry Pi OS Bookworm Lite または Trixie Lite（64-bit）
- H.264/AACまたはHEVC/AACのMP4（1920x1080 / 30fps推奨）
- HDMI接続ディスプレイ、3.5mmアナログ音声出力
- 初期ユーザー名: `pi`

H.264/HEVCはV4L2 M2Mハードウェアデコードを使用します。

## 初回導入

Raspberry Pi ImagerでLite 64-bit OSを書き込み、SSHを有効化して起動します。HDMIと3.5mm音声を接続後、`pi`ユーザーでSSH接続して以下を実行してください。

```bash
sudo apt update
sudo apt -y install git
git clone https://github.com/runsystem-hiro/loop-videos.git /home/pi/loop-videos
cd /home/pi/loop-videos
sudo ./scripts/install.sh
```

`install.sh`は、必要パッケージ導入、ディレクトリ作成、DRM/KMS・3.5mm音声・V4L2の検証、tty1専有、systemd登録と起動を行います。要件を満たさない場合はエラー終了します。

## 動画の配置

Windows PowerShellからMP4を転送します。サービスは動画を検知すると自動で再生します。

```powershell
scp .\*.mp4 pi@<raspi-ip>:/home/pi/loop-videos/videos/active/
```

再生順はファイル名昇順です。停止対象は`videos/backup/`へ移動してください。

## 日常運用

```bash
# 再起動・状態確認
sudo systemctl restart loop-videos.service
sudo systemctl status loop-videos.service --no-pager

# 問題発生時のログ確認
journalctl -u loop-videos.service -n 120 --no-pager
tail -n 120 /home/pi/loop-videos/logs/mpv_drm.log
```

正常時は`loop-videos.service`が`active (running)`となり、ログに次が出力されます。

```text
mpv start (hwdec=v4l2m2m-copy)
Using hardware decoding (v4l2m2m-copy)
```

## 最短の切り分け

```bash
# DRM/KMS、アナログ音声、V4L2デコードを確認
test -c /dev/dri/card0 && echo 'OK: DRM/KMS'
aplay -l | grep -F Headphones && echo 'OK: analog audio'
mpv --hwdec=help | grep -F v4l2m2m && echo 'OK: V4L2 M2M'
```

- 音声が出ない: `aplay -l`で`Headphones`の存在を確認します。
- 映像がカクつく: ログに`Using hardware decoding (v4l2m2m-copy)`があることを確認します。
- tty1でログイン画面が表示される: `systemctl is-enabled getty@tty1.service`が`masked`であることを確認します。

## 復旧

tty1のログイン画面を戻す場合:

```bash
sudo systemctl stop loop-videos.service
sudo systemctl disable loop-videos.service
sudo systemctl unmask getty@tty1.service
sudo systemctl enable --now getty@tty1.service
```

## ディレクトリ構成

```text
/home/pi/loop-videos/
  videos/active/   # 再生対象
  videos/backup/   # 保管用
  scripts/         # 再生・導入スクリプト
  logs/            # mpvログ
```

## License

This project is licensed under the [MIT License](LICENSE).
