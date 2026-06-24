#!/bin/bash

# --- 設定項目 ---
# 移行データを一時的にまとめるフォルダ（USBメモリのパスなどに書き換えてもOKです）
BACKUP_DIR="$HOME/rclone_migration_backup"

echo "=== rclone 設定バックアップ開始 ==="

# バックアップ先フォルダの作成
mkdir -p "$BACKUP_DIR"

# 1. rcloneの設定ファイルのパスを取得してコピー
RCLONE_CONF=$(rclone config file | tail -n 1)
if [ -f "$RCLONE_CONF" ]; then
    cp "$RCLONE_CONF" "$BACKUP_DIR/"
    echo "✔ rclone設定ファイルをコピーしました: $RCLONE_CONF"
else
    echo "❌ rclone設定ファイルが見つかりません。"
    exit 1
fi

# 2. 以前作成したマウントスクリプトも一緒にコピー
if [ -f "$HOME/mount_gdrive.sh" ]; then
    cp "$HOME/mount_gdrive.sh" "$BACKUP_DIR/"
    echo "✔ マウントスクリプト(mount_gdrive.sh)をコピーしました。"
else
    echo "⚠️ mount_gdrive.sh がホームディレクトリに見つかりません（スキップ）。"
fi

echo "----------------------------------------"
echo "完了しました！"
echo "[$BACKUP_DIR] の中身を、新しいPCに持っていってください。"
echo "=== バックアップ終了 ==="
