#!/bin/bash

# --- 設定項目 ---
BACKUP_DIR="$HOME/rclone_migration_backup"
TARGET_CONF_DIR="$HOME/.config/rclone"
XFCE_AUTOSTART_DIR="$HOME/.config/autostart"

echo "=== 新PCへの rclone 復元・自動設定開始 ==="

# 1. 新しいPCに rclone をインストール（未導入の場合）
if ! command -v rclone &> /dev/null; then
    echo "rclone をインストールしています（パスワードが求められる場合があります）..."
    sudo apt update && sudo apt install -y rclone
else
    echo "✔ rclone は既にインストールされています。"
fi

# 2. rclone設定ファイルの配置
mkdir -p "$TARGET_CONF_DIR"
if [ -f "$BACKUP_DIR/rclone.conf" ]; then
    cp "$BACKUP_DIR/rclone.conf" "$TARGET_CONF_DIR/"
    echo "✔ rclone設定ファイルを配置しました。"
else
    echo "❌ バックアップされた rclone.conf が $BACKUP_DIR に見つかりません。"
    exit 1
fi

# 3. マウントスクリプトの配置と権限付与
if [ -f "$BACKUP_DIR/mount_gdrive.sh" ]; then
    cp "$BACKUP_DIR/mount_gdrive.sh" "$HOME/"
    chmod +x "$HOME/mount_gdrive.sh"
    echo "✔ mount_gdrive.sh をホームディレクトリに配置し、実行権限を付与しました。"
else
    echo "⚠️ mount_gdrive.sh がバックアップに見つかりません。"
fi

# 4. Xfceの自動起動（Autostart）への登録
# Xfceは ~/.config/autostart/ 内の .desktop ファイルを読み込んで自動起動します
mkdir -p "$XFCE_AUTOSTART_DIR"
cat << EOF > "$XFCE_AUTOSTART_DIR/rclone_mount.desktop"
[Desktop Entry]
Type=Application
Exec=/home/$USER/mount_gdrive.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Google Drive Auto Mount
Comment=Mount Google Drive using rclone on login
X-GNOME-Autostart-Delay=5
EOF

echo "✔ Xfceのセッション自動起動に登録しました（遅延5秒設定）。"

echo "----------------------------------------"
echo "すべての引っ越し作業が完了しました！"
echo "一度手動で [ ~/mount_gdrive.sh ] を実行するか、再ログインしてみてください。"
echo "=== 復元終了 ==="
