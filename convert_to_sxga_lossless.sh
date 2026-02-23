#!/bin/bash

# ==============================================================================
# Script Name: convert_to_sxga_lossless.sh
# Version:     2.0 (Size-Detection Debug)
# Updated:     2026-02-23
# ==============================================================================

if command -v magick &> /dev/null; then
    IMG_TOOL="magick"
elif command -v convert &> /dev/null; then
    IMG_TOOL="convert"
else
    zenity --error --text="ImageMagickが見つかりません。"
    exit 1
fi

UPSCALED_LIST=""
MAINTAINED_LIST=""

(
    TOTAL=$#
    COUNT=0
    for FILE in "$@"; do
        if [ ! -f "$FILE" ]; then continue; fi

        DIR=$(dirname "$FILE")
        FILENAME=$(basename "$FILE")
        BASENAME="${FILENAME%.*}"
        OUT_FILE="$DIR/${BASENAME}_oversxga.webp"

        # 同名回避
        if [ -f "$OUT_FILE" ]; then
            I=1
            while [ -f "$DIR/${BASENAME}_oversxga_$(printf "%02d" $I).webp" ]; do
                I=$((I + 1))
            done
            OUT_FILE="$DIR/${BASENAME}_oversxga_$(printf "%02d" $I).webp"
        fi

        # 【サイズ取得の強化】 余計な文字を排除して数値のみ抽出
        WIDTH=$($IMG_TOOL identify -format "%w" "$FILE" 2>/dev/null | tr -d '[:space:]')
        HEIGHT=$($IMG_TOOL identify -format "%h" "$FILE" 2>/dev/null | tr -d '[:space:]')

        # デバッグ: サイズが取得できなかった場合の処理
        if [ -z "$WIDTH" ] || [ -z "$HEIGHT" ]; then
             MAINTAINED_LIST+="- $FILENAME (エラー: サイズ取得失敗)\n"
             continue
        fi

        COUNT=$((COUNT + 1))
        PERCENT=$((COUNT * 100 / TOTAL))
        echo "$PERCENT"
        echo "# v2.0 解析中: $FILENAME (${WIDTH}x${HEIGHT})"

        # 【判定ロジック】 1280以上 OR 1024以上 なら維持
        if [ "$WIDTH" -ge 1280 ] || [ "$HEIGHT" -ge 1024 ]; then
            # 維持（縮小しない）
            $IMG_TOOL "$FILE" -background white -alpha remove -alpha off \
                -define webp:lossless=true "$OUT_FILE"
            
            REAL_OUT=$($IMG_TOOL identify -format "%wx%h" "$OUT_FILE" 2>/dev/null)
            MAINTAINED_LIST+="- $FILENAME (解析値: ${WIDTH}x${HEIGHT} -> 実出力: ${REAL_OUT})\n"
        else
            # 拡大
            $IMG_TOOL "$FILE" -background white -alpha remove -alpha off \
                -filter Lanczos -resize "1280x1024" \
                -define webp:lossless=true "$OUT_FILE"
            
            REAL_OUT=$($IMG_TOOL identify -format "%wx%h" "$OUT_FILE" 2>/dev/null)
            UPSCALED_LIST+="- $FILENAME (解析値: ${WIDTH}x${HEIGHT} -> 実出力: ${REAL_OUT})\n"
        fi
    done

    REPORT="/tmp/conversion_report_$$.txt"
    echo -e "■判定：サイズ維持（1280x1024以上の辺あり）\n${MAINTAINED_LIST:-なし}\n" > "$REPORT"
    echo -e "■判定：拡大処理（両方の辺がSXGA未満）\n${UPSCALED_LIST:-なし}" >> "$REPORT"
    
    zenity --text-info --title="変換レポート v2.0" --filename="$REPORT" --width=700 --height=500 --font="Monospace 10" --ok-label="閉じる"
    rm "$REPORT"

) | zenity --progress --title="SXGA変換 v2.0" --text="開始中..." --auto-close --percentage=0
