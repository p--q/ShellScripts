#!/bin/bash

# ==============================================================================
# Script Name: convert_to_sxga_lossless.sh
# Version:     1.1
# Updated:     2026-02-23
# Description: SXGA(1280x1024)より小さい画像のみ拡大し、大きい画像は縮小せずに維持。
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
        
        OUT_FILE="$DIR/${BASENAME}_converted.webp"
        
        if [ -f "$OUT_FILE" ]; then
            I=1
            while [ -f "$DIR/${BASENAME}_converted_$(printf "%02d" $I).webp" ]; do
                I=$((I + 1))
            done
            OUT_FILE="$DIR/${BASENAME}_converted_$(printf "%02d" $I).webp"
        fi

        COUNT=$((COUNT + 1))
        PERCENT=$((COUNT * 100 / TOTAL))
        echo "$PERCENT"
        echo "# 処理中: $FILENAME (v1.1)"

        # ----------------------------------------------------------------------
        # ポイント: "1280x1024<" フラグ
        # 指定サイズより小さい場合のみ拡大（大きい画像はリサイズをスキップ）
        # ----------------------------------------------------------------------
        $IMG_TOOL "$FILE" \
            -background white -alpha remove -alpha off \
            -filter Lanczos \
            -resize "1280x1024<" \
            -define webp:lossless=true \
            "$OUT_FILE"
    done
) | zenity --progress --title="SXGA変換 v1.1" --text="処理を開始します..." --auto-close --percentage=0

zenity --info --title="完了" --text="バージョン1.1の処理が完了しました。\n(大きい画像はサイズを維持しました)" --timeout=3
