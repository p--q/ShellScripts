#!/bin/bash

# =====================================================================
# 【説明】新しいPCへ rclone 環境を丸ごと復元し、自動起動の設定を行います。
# 【前提】前のPCから持ってきた「rclone_backup_folder」を
#         あらかじめ新PCのホームディレクトリ直下に配置しておいてください。
# =====================================================================

BACKUP_DIR="$HOME/rclone_backup_folder"
TARGET_CONF_DIR="$HOME/.config/rclone"
XFCE_AUTOSTART_DIR="$HOME/.config/autostart"

echo "=== 新しいPCへの復元処理を開始します ==="

# 1. rclone のインストール（未導入の場合のみ実行）
if ! command -v rclone &>/dev/null; then
    echo "rclone をシステムにインストールします（パスワード入力を求められます）..."
    sudo apt update && sudo apt install -y rclone
else
    echo "確認：rclone は既にインストールされています。"
fi

# 2. 設定ファイルの復元
mkdir -p "$TARGET_CONF_DIR"
if [ -f "$BACKUP_DIR/rclone.conf" ]; then
    cp "$BACKUP_DIR/rclone.conf" "$TARGET_CONF_DIR/"
    echo "成功：rclone設定ファイルを適切な場所に配置しました。"
else
    echo "エラー：バックアップフォルダ内に rclone.conf が見つかりません。"
    exit 1
fi

# 3. マウントスクリプトの復元と実行権限の付与
if [ -f "$BACKUP_DIR/mount_gdrive.sh" ]; then
    cp "$BACKUP_DIR/mount_gdrive.sh" "$HOME/"
    chmod +x "$HOME/mount_gdrive.sh"
    echo "成功：mount_gdrive.sh をホームに配置し、実行権限を与えました。"
else
    echo "警告：バックアップフォルダ内に mount_gdrive.sh がありません。"
fi

# 4. Xfce環境への自動起動（Autostart）登録ファイルの生成
mkdir -p "$XFCE_AUTOSTART_DIR"
cat << 'SETTING' > "$XFCE_AUTOSTART_DIR/rclone_mount.desktop"
[Desktop Entry]
Type=Application
Exec=/home/$USER/mount_gdrive.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Google Drive Auto Mount
Comment=Mount Google Drive using rclone on login
X-GNOME-Autostart-Delay=5
SETTING

echo "成功：Xfceのログイン時自動起動に登録しました（5秒ディレイ）。"
echo "=== すべての復元工程が完了しました！ ==="
echo "一度ログアウトして再ログインするか、[ ~/mount_gdrive.sh ] を実行してください。"
