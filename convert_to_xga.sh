#!/bin/bash

# ==============================================================================
# Script Name: convert_to_xga.sh
# Description: 画像の長辺をXGA(1024x768)に合わせ、背景白塗りのJPGへ変換。
#              同名ファイルがある場合は「_01」等の連番を付与します。
# Version:     1.2.2
# ==============================================================================

# --- 1. 依存関係チェック ---
if ! command -v zenity &> /dev/null; then
    echo "Error: 'zenity' is required."
    exit 1
fi

if command -v magick &> /dev/null; then
    IMG_TOOL="magick"
elif command -v convert &> /dev/null; then
    IMG_TOOL="convert"
else
    zenity --error --text="ImageMagickがインストールされていません。\nsudo apt install imagemagick を実行してください。"
    exit 1
fi

# --- 2. 引数チェック ---
if [ "$#" -eq 0 ]; then
    zenity --info --title="使い方" --text="画像をドロップするか、右クリックメニューから実行してください。"
    exit 0
fi

# --- 3. メイン処理 ---
(
    COUNT=0
    TOTAL=$#
    for FILE in "$@"; do
        if [ ! -f "$FILE" ]; then continue; fi

        DIR=$(dirname "$FILE")
        FILENAME=$(basename "$FILE")
        BASENAME="${FILENAME%.*}"
        
        # 同名回避ロジック
        OUT_FILE="$DIR/${BASENAME}.jpg"
        if [ -f "$OUT_FILE" ]; then
            I=1
            while [ -f "$DIR/${BASENAME}_$(printf "%02d" $I).jpg" ]; do
                I=$((I + 1))
            done
            OUT_FILE="$DIR/${BASENAME}_$(printf "%02d" $I).jpg"
        fi

        COUNT=$((COUNT + 1))
        PERCENT=$((COUNT * 100 / TOTAL))
        echo "$PERCENT"
        echo "# 処理中: $FILENAME ($COUNT/$TOTAL)"

        # 変換実行
        $IMG_TOOL "$FILE" \
            -background white -alpha remove -alpha off \
            -resize 1024x768 \
            "$OUT_FILE"
    done
) | zenity --progress --title="画像変換 (XGA)" --text="準備中..." --auto-close --percentage=0

# --- 4. 完了通知 ---
MSG=$(echo -e "処理が完了しました！\n元ファイルと同じ場所に保存しました。")
zenity --info --title="完了" --text="$MSG" --timeout=3
