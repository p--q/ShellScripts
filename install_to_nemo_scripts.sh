#!/bin/bash

# ==============================================================================
# Script Name: install_to_nemo_scripts.sh
# Description: ファイルをNemoのスクリプトフォルダへコピーし実行権限を付与します。
# Version:     1.1.3
# ==============================================================================

TARGET_DIR="$HOME/.local/share/nemo/scripts"

# フォルダがない場合は作成
mkdir -p "$TARGET_DIR"

# 引数がない場合の案内
if [ "$#" -eq 0 ]; then
    zenity --info --title="使い方" --text="登録したいスクリプトファイルを右クリックして実行してください。"
    exit 0
fi

# ファイルのコピーと実行権限の付与
for FILE in "$@"; do
    FILENAME=$(basename "$FILE")
    
    # コピー実行
    cp "$FILE" "$TARGET_DIR/"
    
    # 実行権限を付与（ホームディレクトリ配下なので確実に適用されます）
    chmod +x "$TARGET_DIR/$FILENAME"
done

# --- 完了通知 ---
# 改行を含めたメッセージの作成
MSG=$(echo -e "以下のファイルを登録しました：\n$*\n\n右クリックメニューを確認してください。")

zenity --info \
    --title="完了" \
    --text="$MSG" \
    --timeout=3
