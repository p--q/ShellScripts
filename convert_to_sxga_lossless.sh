#!/bin/bash

# ==============================================================================
# Script Name: convert_to_sxga_lossless.sh
# Version:     2.4 (Smart Naming)
# Updated:     2026-02-23
# Description: 1280x1024以上の辺があれば維持、なければ拡大。
#              出力名は基本「元の名前.webp」。重複時のみ連番を付与。
# ==============================================================================

# コマンドのセットアップ
if command -v magick &> /dev/null; then
    CONVERT="magick"
    IDENTIFY="magick identify"
else
    CONVERT="convert"
    IDENTIFY="identify"
fi

REPORT_LIST=""

(
    TOTAL=$#
    COUNT=0
    for FILE in "$@"; do
        [ ! -f "$FILE" ] && continue

        DIR=$(dirname "$FILE")
        BASENAME=$(basename "${FILE%.*}")
        
        # 1. まずは「元の名前.webp」を試みる
        OUT_FILE="$DIR/${BASENAME}.webp"

        # 2. 同名のファイル（ソース自身、または既存のwebp）がある場合のみ連番を付与
        #    ※元のファイルが .webp だった場合も考慮し、上書きを防ぎます
        if [ -f "$OUT_FILE" ]; then
            I=1
            while [ -f "$DIR/${BASENAME}_$(printf "%02d" $I).webp" ]; do
                I=$((I + 1))
            done
            OUT_FILE="$DIR/${BASENAME}_$(printf "%02d" $I).webp"
        fi

        # サイズ取得
        SIZE_INFO=$($IDENTIFY -ping -format "%w %h" "$FILE" 2>/dev/null)
        read -r W H <<< "$SIZE_INFO"

        if [[ ! "$W" =~ ^[0-9]+$ ]]; then
             REPORT_LIST+="[失敗] $BASENAME (サイズ取得不能)\n"
             continue
        fi

        COUNT=$((COUNT + 1))
        PERCENT=$((COUNT * 100 / TOTAL))
        echo "$PERCENT"
        echo "# 処理中: $BASENAME (${W}x${HEIGHT})"

        OPTS="-background white -alpha remove -alpha off -define webp:lossless=true"

        # 判定
        if [ "$W" -ge 1280 ] || [ "$H" -ge 1024 ]; then
            $CONVERT "$FILE" $OPTS "$OUT_FILE"
            STATUS="維持"
        else
            $CONVERT "$FILE" $OPTS -filter Lanczos -resize "1280x1024" "$OUT_FILE"
            STATUS="拡大"
        fi

        NEW_SIZE=$($IDENTIFY -ping -format "%wx%h" "$OUT_FILE" 2>/dev/null)
        REPORT_LIST+="[$STATUS] $BASENAME -> $(basename "$OUT_FILE") (${W}x${H} -> $NEW_SIZE)\n"
    done

    echo -e "$REPORT_LIST" | zenity --text-info \
        --title="変換完了 (v2.4)" \
        --width=700 --height=450 \
        --ok-label="閉じる" \
        --font="Monospace 10"

) | zenity --progress --title="SXGA変換" --text="開始中..." --auto-close --percentage=0
