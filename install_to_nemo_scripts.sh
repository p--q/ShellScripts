#!/bin/bash

# ==============================================================================
# Script Name: install_to_nemo_scripts.sh
# Description: ファイルをNemoのスクリプトフォルダへコピーし実行権限を付与、Nemoを再起動。
# Version:     1.1.0
# ==============================================================================

TARGET_DIR="$HOME/.local/share/nemo/scripts"

# フォルダがない場合は作成
mkdir -p "$TARGET_DIR"

if [ "$#" -eq 0 ]; then
    zenity --info --title="使い方" --text="登録したいスクリプトファイルを右クリックして実行してください。"
    exit 0
fi

# ファイルのコピーと権限付与
for FILE in "$@"; do
    FILENAME=$(basename "$FILE")
    cp "$FILE" "$TARGET_DIR/"
    chmod +x "$TARGET_DIR/$FILENAME"
done

# --- Nemoの確実な再起動 ---
# Nemoを完全に終了
nemo -q

# プロセスが終了するのを少し待つ
sleep 1

# バックグラウンドでNemoをデスクトップ管理モードで再開
nohup nemo -n > /dev/null 2>&1 &

zenity --info --title="完了" --text="以下のファイルを登録しました：\n$*\n\n右クリックメニューが更新されました。" --timeout=3
