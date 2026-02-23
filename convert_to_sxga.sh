#!/bin/bash

# ==============================================================================
# Script Name: convert_to_sxga.sh
# Version:     3.3 (Diagnostic Enhanced)
# Updated:     2026-02-23
# ==============================================================================

# --- 依存コマンドのチェック ---
MISSING_TOOLS=""
command -v magick &> /dev/null || command -v convert &> /dev/null || MISSING_TOOLS+="ImageMagick "
command -v pdftoppm &> /dev/null || MISSING_TOOLS+="poppler-utils(pdftoppm) "
command -v pdfinfo &> /dev/null || MISSING_TOOLS+="poppler-utils(pdfinfo) "

if [ -n "$MISSING_TOOLS" ]; then
    zenity --error --title="エラー" --text="以下のツールが必要です:\n$MISSING_TOOLS"
    exit 1
fi

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
            while [ -f "$DIR/${BASENAME}_$(printf "%02d" $I).webp" ]; do
                I=$((I + 1))
            done
            OUT_FILE="$DIR/${BASENAME}_$(printf "%02d" $I).webp"
        fi

        COUNT=$((COUNT + 1))
        PERCENT=$((COUNT * 100 / TOTAL))
        echo "$PERCENT"

        # --- PDF処理 ---
        if [ "$EXT_LOWER" = "pdf" ]; then
            echo "# PDFを確認中: $BASENAME"
            PAGES=$(pdfinfo "$ABS_FILE" 2>/dev/null | grep "Pages:" | grep -oE '[0-9]+')
            
            if [ "$PAGES" -eq 1 ]; then
                TEMP_BASE="/tmp/${BASENAME}_pdf_$(date +%s%N)"
                # pdftoppm の実行結果（標準エラー）を取得
                PDF_ERR=$(pdftoppm -f 1 -l 1 -singlefile -png -r 300 "$ABS_FILE" "$TEMP_BASE" 2>&1)
                
                if [ -f "${TEMP_BASE}.png" ]; then
                    PROC_FILE="${TEMP_BASE}.png"
                    IS_PDF_TMP=true
                else
                    REPORT_LIST+="[失敗] $BASENAME (PDF読み込みエラー: $PDF_ERR)\n"
                    continue
                fi
            else
                REPORT_LIST+="[スキップ] $BASENAME (ページ数: $PAGES)\n"
                continue
            fi
        else
            PROC_FILE="$ABS_FILE"
            IS_PDF_TMP=false
        fi

        # --- 共通画像処理 ---
        echo "# 処理中: $BASENAME"
        SIZE_INFO=$($IDENTIFY -ping -format "%w %h" "$PROC_FILE" 2>/dev/null)
        read -r W H <<< "$SIZE_INFO"

        if [[ ! "$W" =~ ^[0-9]+$ ]]; then
             REPORT_LIST+="[失敗] $BASENAME (サイズ解析不能)\n"
             [ "$IS_PDF_TMP" = true ] && rm "$PROC_FILE"
             continue
        fi

        OPTS="-background white -alpha remove -alpha off -quality 90"

        if [ "$W" -ge 1280 ] || [ "$H" -ge 1024 ]; then
            $CONVERT "$PROC_FILE" $OPTS "$OUT_FILE"
            STATUS="維持"
        else
            $CONVERT "$PROC_FILE" $OPTS -filter Lanczos -resize "1280x1024" "$OUT_FILE"
            STATUS="拡大"
        fi

        [ "$EXT_LOWER" = "pdf" ] && STATUS="PDF->$STATUS"
        NEW_SIZE=$($IDENTIFY -ping -format "%wx%h" "$OUT_FILE" 2>/dev/null)
        REPORT_LIST+="[$STATUS] $BASENAME -> $(basename "$OUT_FILE") (${W}x${H} -> $NEW_SIZE)\n"

        [ "$IS_PDF_TMP" = true ] && rm "$PROC_FILE"
    done

    echo -e "$REPORT_LIST" | zenity --text-info \
        --title="変換完了 (v3.3)" \
        --width=750 --height=450 --ok-label="閉じる" --font="Monospace 10"

) | zenity --progress --title="SXGA変換" --text="開始中..." --auto-close --percentage=0
