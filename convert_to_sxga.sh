#!/bin/bash

# ==============================================================================
# Script Name: convert_to_sxga.sh
# Version:     3.7 (Zero-Dependency Calculation)
# Updated:     2026-02-23
#
# [解説]
# 1. 画像および1ページのみのPDFを「SXGA（1280x1024）」基準で変換。
# 2. 外部コマンド(bc)に頼らずシェル標準機能でサイズ計算を行うよう修正。
# 3. 複数ページのPDFはスキップ理由を明記して安全に処理。
# ==============================================================================

# --- 依存チェック ---
if ! command -v zenity &> /dev/null; then
    echo "Error: zenity is not installed."
    exit 1
fi

# ファイルサイズを読みやすい単位に変換する関数（bc不要版）
format_size() {
    local size=$1
    if [ "$size" -lt 1024 ]; then
        echo "${size}B"
    elif [ "$size" -lt 1048576 ]; then
        # KB計算（小数点以下を擬似的に表示）
        echo "$((size / 1024)).$(((size % 1024) * 10 / 1024))KB"
    else
        # MB計算
        echo "$((size / 1048576)).$(((size % 1048576) * 10 / 1048576))MB"
    fi
}

REPORT_LIST=""

(
    TOTAL=$#
    COUNT=0
    
    # 実行場所の解決
    [ -n "$1" ] && cd "$(dirname "$1")" 2>/dev/null

    for FILE in "$@"; do
        [ ! -f "$FILE" ] && continue
        
        ABS_FILE=$(realpath "$FILE")
        DIR=$(dirname "$ABS_FILE")
        BASENAME=$(basename "${ABS_FILE%.*}")
        EXT_LOWER=$(echo "${ABS_FILE##*.}" | tr '[:upper:]' '[:lower:]')
        OUT_FILE="$DIR/${BASENAME}.webp"

        # 元のサイズ取得
        OLD_SIZE_RAW=$(stat -c%s "$ABS_FILE" 2>/dev/null || echo 0)
        OLD_SIZE_HUMAN=$(format_size "$OLD_SIZE_RAW")

        # 同名回避
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
                pdftoppm -f 1 -l 1 -singlefile -png -r 300 "$ABS_FILE" "${TEMP_PNG%.png}" 2>/dev/null
                if [ -f "$TEMP_PNG" ]; then
                    PROC_FILE="$TEMP_PNG"
                    IS_PDF_TMP=true
                else
                    REPORT_LIST+="[失敗] $BASENAME (PDF画像化失敗)\n"
                    continue
                fi
            else
                REPORT_LIST+="[スキップ] $BASENAME (複数ページあるため変換不可: ${PAGES}P)\n"
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
            
            NEW_SIZE_RAW=$(stat -c%s "$OUT_FILE" 2>/dev/null || echo 0)
            NEW_SIZE_HUMAN=$(format_size "$NEW_SIZE_RAW")
            NEW_DIM=$($ID_CMD -ping -format "%wx%h" "$OUT_FILE" 2>/dev/null)

            REPORT_LIST+="[$STATUS] $BASENAME\n    └ $NEW_DIM | $OLD_SIZE_HUMAN -> $NEW_SIZE_HUMAN\n"
        else
            REPORT_LIST+="[失敗] $BASENAME (サイズ解析不能)\n"
        fi

        [ "$IS_PDF_TMP" = true ] && rm -f "$PROC_FILE"
    done

    echo -e "$REPORT_LIST" | zenity --text-info \
        --title="変換完了 (v3.7)" \
        --width=750 --height=500 \
        --ok-label="閉じる" \
        --font="Monospace 10"

) | zenity --progress --title="SXGA変換" --text="処理を開始しています..." --auto-close --percentage=0
