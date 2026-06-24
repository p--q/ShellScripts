#!/bin/bash

# --- 設定項目 ---
REMOTE_NAME="gdrive"
MOUNT_POINT="$HOME/GoogleDrive"

echo "=== Google Drive 自動マウントスクリプト開始 ==="

# 1. マウント先ディレクトリが存在しない場合は作成
if [ ! -d "$MOUNT_POINT" ]; then
    echo "マウント用ディレクトリを作成します: $MOUNT_POINT"
    mkdir -p "$MOUNT_POINT"
fi

# 2. 既存の幽霊マウントやrcloneプロセスを大掃除
echo "古いマウントとプロセスを解除しています..."
fusermount -uz "$MOUNT_POINT" 2>/dev/null
killall rclone 2>/dev/null
sleep 1

# 3. rcloneマウントを実行（バックグラウンド）
echo "rcloneでGoogleドライブをマウントします..."
rclone mount "$REMOTE_NAME": "$MOUNT_POINT" --vfs-cache-mode writes &

# 4. マウントが完了するまで少し待機（最大10秒）
echo "接続の確立を待っています..."
for i in {1..10}; do
    if mountpoint -q "$MOUNT_POINT"; then
        echo "マウントが成功しました！"
        break
    fi
    sleep 1
done

# 5. Thunarのキャッシュをリフレッシュ（ここがポイント！）
if pgrep -x "thunar" > /dev/null; then
    echo "Thunarのキャッシュをリフレッシュしています..."
    thunar -q
fi

echo "=== すべての処理が完了しました ==="
