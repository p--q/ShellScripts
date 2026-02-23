#!/bin/bash

# ==============================================================================
# Script Name: install_to_nemo_scripts.sh
# Description: ファイルをNemoのスクリプトフォルダへコピーし実行権限を付与、Nemoを再起動。
# Version:     1.1.1
# ==============================================================================

TARGET_DIR="$HOME/.local/share/nemo/scripts"
mkdir -p "$TARGET_DIR"

if [ "$#" -eq 0 ]; then
    zenity --info --title="使い方" --text="登録したいスクリプトファイルを右クリックして実行してください。"
    exit 0
fi

for FILE in "$@"; do
    FILENAME=$(basename "$FILE")
    cp "$FILE" "$TARGET_DIR/"
    chmod +x "$TARGET_DIR/$FILENAME"
done

# Nemoの再起動
nemo -q
sleep 1
nohup nemo -n > /dev/null 2>&1 &

# 完了通知
MSG=$(echo -e "以下のファイルを登録しました：\n$*\n\n右クリックメニューが更新されました。")
zenity --info --title="完了" --text="$MSG" --timeout=3
