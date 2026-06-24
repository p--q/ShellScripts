#!/bin/bash

# =====================================================================
# 【説明】現在のPCの rclone 設定とマウントスクリプトをバックアップします。
# 【使い方】このスクリプトを実行すると、ホームに「rclone_backup_folder」が作られます。
#           そのフォルダをUSBメモリ等で新しいPCへ持っていってください。
# =====================================================================

BACKUP_DIR="$HOME/rclone_backup_folder"

echo "=== rclone バックアップ処理を開始します ==="

# バックアップ先フォルダの作成
mkdir -p "$BACKUP_DIR"

# rclone設定ファイルの場所を特定してコピー
RCLONE_CONF=$(rclone config file | tail -n 1)
if [ -f "$RCLONE_CONF" ]; then
    cp "$RCLONE_CONF" "$BACKUP_DIR/"
    echo "成功：設定ファイルをコピーしました。"
else
    echo "エラー：rcloneの設定ファイルが見つかりません。"
    exit 1
fi

# マウント用スクリプトの同期
if [ -f "$HOME/mount_gdrive.sh" ]; then
    cp "$HOME/mount_gdrive.sh" "$BACKUP_DIR/"
    echo "成功：マウントスクリプトをコピーしました。"
else
    echo "警告：ホームディレクトリに mount_gdrive.sh が見つかりません。"
fi

echo "=== バックアップが完了しました！ ==="
echo "生成されたフォルダ [ $BACKUP_DIR ] を新しいPCに移行してください。"
