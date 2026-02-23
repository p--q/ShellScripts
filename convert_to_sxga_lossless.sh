#!/bin/bash

# ==============================================================================
# Script Name: convert_to_sxga_lossless_smart.sh
# Description: 1280x1024より大きい場合のみ縮小。それ以外はサイズ維持。
#              WebP Lossless変換 + 透明背景の白埋め。
# ==============================================================================

if command -v magick &> /dev/null; then
    IMG_TOOL="magick"
elif command -v convert &> /dev/null; then
    IMG_TOOL="convert"
else
    zenity --error --text="ImageMagickがインストールされていません。"
    exit 1
fi

if [ "$#" -eq 0 ]; then
    zenity --info --title="使い方" --text="画像を右クリックメニューから実行してください。"
    exit 0
fi

(
    COUNT=0
    TOTAL=$#
    for FILE in "$@"; do
        if [ ! -f "$FILE" ]; then continue; fi

        DIR=$(dirname "$FILE")
        FILENAME=$(basename "$FILE")
        BASENAME="${FILENAME%.*}"
        
        OUT_FILE="$DIR/${BASENAME}_sxga.webp"
        
        if [ -f "$OUT_FILE" ]; then
            I=1
            while [ -f "$DIR/${BASENAME}_sxga_$(printf "%02d" $I).webp" ]; do
                I=$((I + 1))
            done
            OUT_FILE="$DIR/${BASENAME}_sxga_$(printf "%02d" $I).webp"
        fi

        COUNT=$((COUNT + 1))
        PERCENT=$((COUNT * 100 / TOTAL))
        echo "$PERCENT"
        echo "# 処理中: $FILENAME"

        # --- 変換実行のポイント ---
        # 1280x1024> : 「>」フラグは、元の画像が指定サイズより大きい場合のみ縮小します。
        # 小さい画像を引き伸ばす（ボケる）のを防ぎつつ、巨大な画像だけを抑えます。
        $IMG_TOOL "$FILE" \
            -background white -alpha remove -alpha off \
            -filter Lanczos \
            -resize "1280x1024>" \
            -define webp:lossless=true \
            "$OUT_FILE"
    done
) | zenity --progress --title="スマートSXGA変換" --text="処理を開始します..." --auto-close --percentage=0

zenity --info --title="完了" --text="処理が完了しました。\n(大きい画像のみSXGAへ縮小されました)" --timeout=3
