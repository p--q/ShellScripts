#!/bin/bash

# ==============================================================================
# Script Name: convert_to_sxga.sh
# Version:     3.6 (Size Comparison Edition)
# Updated:     2026-02-23
#
# [解説]
# 1. 画像および1ページのみのPDFを「SXGA（1280x1024）」基準で変換。
# 2. 変換前後のファイルサイズ（例: 1.2MB -> 450KB）をレポートに表示。
# 3. 複数ページのPDFはスキップし、その旨を明記。
# ==============================================================================

# --- 依存チェック ---
if ! command -v zenity &> /dev/null; then
    echo "Error: zenity is not installed."
    exit 1
fi

# ファイルサイズを読みやすい単位に変換する関数
format_size() {
    local size=$1
    if [ "$size" -lt 1024 ]; then
        echo "${size}B"
    elif [ "$size" -lt 1048576 ]; then
        echo "$(echo "scale=1; $size/1024" | bc)KB"
    else
        echo "$(echo "scale=1; $size/1048576" | bc)MB"
    fi
}

REPORT_LIST=""

(
    TOTAL=$#
    COUNT=0
    
    [ -n "$1" ] && cd "$(dirname "$1")"

    for FILE in "$@"; do
        [ ! -f "$FILE" ] && continue
        
        ABS_FILE=$(realpath "$FILE")
        DIR=$(dirname "$ABS_FILE")
        BASENAME=$(basename "${ABS_FILE%.*}")
        EXT_LOWER=$(echo "${ABS_FILE##*.}" | tr '[:upper:]' '[:lower:]')
        OUT_FILE="$DIR/${BASENAME}.webp"

        # 元のファイルサイズ取得
        OLD_SIZE_RAW=$(stat -c%s "$ABS_FILE")
        OLD_SIZE_HUMAN=$(format_size "$OLD_SIZE_RAW")

        if [ -f "$OUT_FILE" ]; then
            I=1
            while [ -f "$DIR/${BASENAME}_$I.webp" ]; do I=$((I+1)); done
            OUT_FILE="$DIR/${BASENAME}_$I.webp"
        fi

        COUNT=$((COUNT + 1))
        echo "$((COUNT * 100 / TOTAL))"
        echo "# 処理中: $BASENAME"

        # --- PDF処理 ---
        if [ "$EXT_LOWER" = "pdf" ]; then
            PAGES_STR=$(pdfinfo "$ABS_FILE" 2>/dev/null | grep "Pages:" | grep -oE '[0-9]+')
            PAGES=${PAGES_STR:-0}

            if [ "$PAGES" -eq 1 ]; then
                TEMP_PNG="/tmp/pdf_tmp_$(date +%s%N).png"
                pdftoppm -f 1 -l 1 -singlefile -png -r 300 "$ABS_FILE" "${TEMP_PNG%.png}"
                if [ -f "$TEMP_PNG" ]; then
                    PROC_FILE="$TEMP_PNG"
                    IS_PDF_TMP=true
                else
                    REPORT_LIST+="[失敗] $BASENAME (画像化失敗)\n"
                    continue
                fi
            else
                REPORT_LIST+="[スキップ] $BASENAME (複数ページあるため変換できません: ${PAGES}ページ)\n"
                continue
            fi
        else
            PROC_FILE="$ABS_FILE"
            IS_PDF_TMP=false
        fi

        # --- 画像解析と変換 ---
        CMD=$(command -v magick || command -v convert)
        ID_CMD=$(command -v identify || echo "magick identify")

        SIZE_INFO=$($ID_CMD -ping -format "%w %h" "$PROC_FILE" 2>/dev/null)
        read -r W H <<< "$SIZE_
