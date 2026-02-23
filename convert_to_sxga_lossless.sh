#!/bin/bash

# ==============================================================================
# Script Name: convert_to_sxga_lossless.sh
# Version:     1.6
# Updated:     2026-02-23
# Description: 横1280以上、または縦1024以上の場合はサイズ維持。
#              それ以外は、アスペクト比を維持しつつ最大SXGAまで拡大。
#              出力ファイル名に "_oversxga" を付与。
# ==============================================================================

if command -v magick &> /dev/null; then
    IMG_TOOL="magick"
elif command -v convert &> /dev/null; then
    IMG_TOOL="convert"
else
    zenity --error --text="ImageMagickがインストールされていません。"
    exit 1
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
        
        # 出力ファイル名を _oversxga に変更
        OUT_FILE="$DIR/${BASENAME}_oversxga.webp"

        # 同名ファイルがある場合の連番処理
        if [ -f "$OUT_FILE" ]; then
            I=1
            while [ -f "$DIR/${BASENAME}_oversxga_$(printf "%02d" $I).webp" ]; do
                I=$((I + 1))
            done
            OUT_FILE="$DIR/${BASENAME}_oversxga_$(printf "%02d" $I).webp"
        fi

        # サイズ取得
        WIDTH=$($IMG_TOOL identify -format "%w" "$FILE")
        HEIGHT=$($IMG_TOOL identify -format "%h" "$FILE")

        COUNT=$((COUNT + 1))
        PERCENT=$((COUNT * 100 / TOTAL))
        echo "$PERCENT"
        echo "# 処理中: $FILENAME"

        # ロジック：横1280以上、または縦1024以上なら「サイズ維持」
        if [ "$WIDTH" -ge 1280 ] || [ "$HEIGHT" -ge 1024 ]; then
            $IMG_TOOL "$FILE" -background white -alpha remove -alpha off \
                -define webp:lossless=true "$OUT_FILE"
            MAINTAINED_LIST+="- $FILENAME (維持: ${WIDTH}x${HEIGHT})\n"
        else
            # 両方の辺がSXGA未満なら「拡大」
            $IMG_TOOL "$FILE" -background white -alpha remove -alpha off \
                -filter Lanczos -resize "1280x1024" -define webp:lossless=true "$OUT_FILE"
            
            NEW_SIZE=$($IMG_TOOL identify -format "%wx%h" "$OUT_FILE")
            UPSCALED_LIST+="- $FILENAME (${WIDTH}x${HEIGHT} -> ${NEW_SIZE})\n"
        fi
    done

    # レポート作成
    REPORT="/tmp/conversion_report_$$.txt"
    echo -e "【サイズ維持（条件合致）】\n${MAINTAINED_LIST:-なし}\n\n【拡大処理（実施）】\n${UPSCALED_LIST:-なし}" > "$REPORT"
    
    zenity --text-info --title="変換レポート v1.6" --filename="$REPORT" --width=600 --height=450 --font="Monospace 10"
    rm "$REPORT"

) | zenity --progress --title="SXGA変換 v1.6" --text="処理中..." --auto-close --percentage=0
