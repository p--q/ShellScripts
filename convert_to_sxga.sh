#!/bin/bash

# ==============================================================================
# Script Name: convert_to_sxga.sh
# Version:     3.5 (Enhanced Skip Messaging)
# Updated:     2026-02-23
#
# [解説]
# 1. 画像および1ページのみのPDFを「SXGA（1280x1024）」基準で変換します。
# 2. 複数ページのPDFはデータの欠落を防ぐため、明確な理由を添えてスキップします。
# 3. すべて「Lossy WebP (Quality 90)」で出力し、高画質と軽量化を両立します。
# ==============================================================================

# --- 依存チェック ---
if ! command -v zenity &> /dev/null; then
    echo "Error: zenity is not installed."
    exit 1
fi

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
                # 複数ページの場合のメッセージをより具体的に修正
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
        read -r W H <<< "$SIZE_INFO"

        if [[ "$W" =~ ^[0-9]+$ ]]; then
            OPTS="-background white -alpha remove -alpha off -quality 90"
            if [ "$W" -ge 1280 ] || [ "$H" -ge 1024 ]; then
                $CMD "$PROC_FILE" $OPTS "$OUT_FILE"
                STATUS="維持"
            else
                $CMD "$PROC_FILE" $OPTS -filter Lanczos -resize "1280x1024" "$OUT_FILE"
                STATUS="拡大"
            fi
            
            [ "$EXT_LOWER" = "pdf" ] && STATUS="PDF->$STATUS"
            NEW_SIZE=$($ID_CMD -ping -format "%wx%h" "$OUT_FILE" 2>/dev/null)
            REPORT_LIST+="[$STATUS] $BASENAME -> $(basename "$OUT_FILE") ($NEW_SIZE)\n"
        else
            REPORT_LIST+="[失敗] $BASENAME (サイズ解析不能)\n"
        fi

        [ "$IS_PDF_TMP" = true ] && rm -f "$PROC_FILE"
    done

    echo -e "$REPORT_LIST" | zenity --text-info \
        --title="変換完了 (v3.5)" \
        --width=700 --height=450 \
        --ok-label="閉じる" \
        --font="Monospace 10"

) | zenity --progress --title="SXGA変換" --text="準備中..." --auto-close --percentage=0
