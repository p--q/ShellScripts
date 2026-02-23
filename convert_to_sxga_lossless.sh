#!/bin/bash

# ==============================================================================
# Script Name: convert_to_sxga_lossless.sh
# Version:     2.2 (Command Fix)
# Updated:     2026-02-23
# ==============================================================================

# コマンドの存在確認
if command -v magick &> /dev/null; then
    IMG_CONVERT="magick"
    IMG_IDENTIFY="magick identify"
elif command -v convert &> /dev/null; then
    IMG_CONVERT="convert"
    IMG_IDENTIFY="identify"
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

        # 【修正】 identify コマンドを正しく呼び出す
        # 以前のバージョンではここが変数の重複で間違っていました
        RAW_INFO=$($IMG_IDENTIFY -ping -format "%w %h" "$FILE" 2>/dev/null)
        
        WIDTH=$(echo "$RAW_INFO" | awk '{print $1}' | tr -d '[:space:]')
        HEIGHT=$(echo "$RAW_INFO" | awk '{print $2}' | tr -d '[:space:]')

        # デバッグ：数値が取れなかった場合
        if [[ ! "$WIDTH" =~ ^[0-9]+$ ]]; then
             MAINTAINED_LIST+="- $FILENAME (取得失敗: $RAW_INFO)\n"
             continue
        fi

        COUNT=$((COUNT + 1))
        PERCENT=$((COUNT * 100 / TOTAL))
        echo "$PERCENT"
        echo "# v2.2 解析中: $FILENAME (${WIDTH}x${HEIGHT})"

        # 判定：横1280以上 OR 縦1024以上 なら維持
        if [ "$WIDTH" -ge 1280 ] || [ "$HEIGHT" -ge 1024 ]; then
            $IMG_CONVERT "$FILE" -background white -alpha remove -alpha off \
                -define webp:lossless=true "$OUT_FILE"
            
            REAL_OUT=$($IMG_IDENTIFY -ping -format "%wx%h" "$OUT_FILE" 2>/dev/null)
            MAINTAINED_LIST+="- $FILENAME (維持: ${WIDTH}x${HEIGHT} -> 実出力: ${REAL_OUT})\n"
        else
            # 拡大
            $IMG_CONVERT "$FILE" -background white -alpha remove -alpha off \
                -filter Lanczos -resize "1280x1024" \
                -define webp:lossless=true "$OUT_FILE"
            
            REAL_OUT=$($IMG_IDENTIFY -ping -format "%wx%h" "$OUT_FILE" 2>/dev/null)
            UPSCALED_LIST+="- $FILENAME (拡大: ${WIDTH}x${HEIGHT} -> 実出力: ${REAL_OUT})\n"
        fi
    done

    REPORT="/tmp/conversion_report_$$.txt"
    echo -e "■サイズ維持またはエラー（拡大なし）\n${MAINTAINED_LIST:-なし}\n" > "$REPORT"
    echo -e "■拡大処理を実施\n${UPSCALED_LIST:-なし}" >> "$REPORT"
    
    zenity --text-info --title="変換レポート v2.2" --filename="$REPORT" --width=700 --height=500 --font="Monospace 10" --ok-label="閉じる"
    rm "$REPORT"

) | zenity --progress --title="SXGA変換 v2.2" --text="開始中..." --auto-close --percentage=0
