#!/bin/bash

# ==============================================================================
# Script Name: install_to_nemo_scripts.sh
# Description: 選択したファイルをNemoのスクリプトフォルダへコピーし実行権限を付与します。
# Version:     1.0.0
# ==============================================================================

TARGET_DIR="$HOME/.local/share/nemo/scripts"

# フォルダがない場合は作成
mkdir -p "$TARGET_DIR"

if [ "$#" -eq 0 ]; then
    zenity --info --title="使い方" --text="Nemoスクリプトに登録したいファイルを右クリックして実行してください。"
    exit 0
fi

for FILE in "$@"; do
    FILENAME=$(basename "$FILE")
    
    # コピー実行
    cp "$FILE" "$TARGET_DIR/"
    
    # 実行権限を付与（ホームディレクトリ内なので確実に成功します）
    chmod +x "$TARGET_DIR/$FILENAME"
done

# Nemoを再起動してメニューを更新
nemo -q

zenity --info --title="完了" --text="以下のファイルをスクリプトフォルダに登録しました：\n$*\n\nNemoを再起動しました。" --timeout=3
