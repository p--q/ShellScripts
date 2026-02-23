#!/bin/bash

# ==============================================================================
# Script Name: convert_to_sxga_lossless.sh
# Version:     1.3
# Updated:     2026-02-23
# Description: 一辺でもSXGA(1280x1024)より小さければ拡大。
#              両辺ともSXGA以上ならサイズ維持。最後に詳細レポートを表示。
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

        # 【判定ロジックの修正】
        # 横が1280未満、または縦が1024未満であれば拡大処理へ
        if [ "$WIDTH" -lt 1280 ] || [ "$HEIGHT" -lt 1024 ]; then
            # -resize "1280x1024" はアスペクト比を維持して枠に収まる最大まで拡大します
            $IMG_TOOL "$FILE" -background white -alpha remove -alpha off \
                -filter Lanczos -resize "1280x1024" -define webp:lossless=true "$OUT_FILE"
            
            # 変換後のサイズを確認
            NEW_SIZE=$($IMG_TOOL identify -format "%wx%h" "$OUT_FILE")
            UPSCALED_LIST+="- $FILENAME (${WIDTH}x${HEIGHT} -> ${NEW_SIZE})\n"
        else
            # すでにSXGA以上の場合はサイズ維持
            $IMG_TOOL "$FILE" -background white -alpha remove -alpha off \
                -define webp:lossless=true "$OUT_FILE"
            MAINTAINED_LIST+="- $FILENAME (維持: ${WIDTH}x${HEIGHT})\n"
        fi
    done

    # レポート作成
    REPORT="/tmp/conversion_report_$$.txt"
    echo -e "【拡大処理（SXGA枠へ）】\n${UPSCALED_LIST:-なし}\n\n【サイズ維持（SXGA以上）】\n${MAINTAINED_LIST:-なし}" > "$REPORT"
    
    zenity --text-info --title="変換レポート v1.3" --filename="$REPORT" --width=600 --height=450 --font="Monospace 10"
    rm "$REPORT"

) | zenity --progress --title="SXGA変換 v1.3" --text="解析中..." --auto-close --percentage=0
