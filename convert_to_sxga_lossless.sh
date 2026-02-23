#!/bin/bash

# ==============================================================================
# Script Name: convert_to_sxga_lossless.sh
# Version:     1.2
# Updated:     2026-02-23
# Description: SXGA(1280x1024)より小さい画像のみ拡大。
#              大きい画像はサイズ維持。最後に処理内訳を表示。
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

UPSCALED_LIST=""
MAINTAINED_LIST=""

(
    COUNT=0
    TOTAL=$#
    for FILE in "$@"; do
        if [ ! -f "$FILE" ]; then continue; fi

        DIR=$(dirname "$FILE")
        FILENAME=$(basename "$FILE")
        BASENAME="${FILENAME%.*}"
        OUT_FILE="$DIR/${BASENAME}_converted.webp"

        # 同名回避
        if [ -f "$OUT_FILE" ]; then
            I=1
            while [ -f "$DIR/${BASENAME}_converted_$(printf "%02d" $I).webp" ]; do
                I=$((I + 1))
            done
            OUT_FILE="$DIR/${BASENAME}_converted_$(printf "%02d" $I).webp"
        fi

        # 現在のサイズを取得
        WIDTH=$($IMG_TOOL identify -format "%w" "$FILE")
        HEIGHT=$($IMG_TOOL identify -format "%h" "$FILE")

        COUNT=$((COUNT + 1))
        PERCENT=$((COUNT * 100 / TOTAL))
        echo "$PERCENT"
        echo "# 処理中: $FILENAME"

        # SXGA(1280x1024)と比較して判定
        # 横幅が1280未満、かつ高さが1024未満の場合に拡大
        if [ "$WIDTH" -lt 1280 ] && [ "$HEIGHT" -lt 1024 ]; then
            $IMG_TOOL "$FILE" -background white -alpha remove -alpha off \
                -filter Lanczos -resize "1280x1024" -define webp:lossless=true "$OUT_FILE"
            UPSCALED_LIST+="- $FILENAME (拡大: ${WIDTH}x${HEIGHT} -> 変換後)\n"
        else
            $IMG_TOOL "$FILE" -background white -alpha remove -alpha off \
                -define webp:lossless=true "$OUT_FILE"
            MAINTAINED_LIST+="- $FILENAME (維持: ${WIDTH}x${HEIGHT})\n"
        fi
    done

    # 結果表示用の一時ファイル作成
    REPORT="/tmp/conversion_report_$$.txt"
    echo -e "【拡大されたファイル】\n${UPSCALED_LIST:-なし}\n\n【サイズ維持されたファイル】\n${MAINTAINED_LIST:-なし}" > "$REPORT"
    
    zenity --text-info --title="処理結果報告 v1.2" --filename="$REPORT" --width=500 --height=400
    rm "$REPORT"

) | zenity --progress --title="SXGA変換 v1.2" --text="解析中..." --auto-close --percentage=0
