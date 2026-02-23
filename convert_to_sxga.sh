#!/bin/bash

# ==============================================================================
# Script Name: convert_to_sxga.sh
# Version:     3.1 (Robust PDF Support)
# Updated:     2026-02-23
# Description: すべての出力を Lossy WebP に統一。
#              1280x1024未満は拡大、それ以上は維持。
#              1ページのみのPDFを確実に判定して変換します。
# ==============================================================================

# --- 依存コマンドのチェック ---
MISSING_TOOLS=""
command -v magick &> /dev/null || command -v convert &> /dev/null || MISSING_TOOLS+="ImageMagick "
command -v pdftoppm &> /dev/null || MISSING_TOOLS+="poppler-utils(pdftoppm) "
command -v pdfinfo &> /dev/null || MISSING_TOOLS+="poppler-utils(pdfinfo) "

if [ -n "$MISSING_TOOLS" ]; then
    zenity --error --title="エラー" --text="以下のツールが必要です。インストールしてください:\n$MISSING_TOOLS"
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
    for FILE in "$@"; do
        [ ! -f "$FILE" ] && continue

        DIR=$(dirname "$FILE")
        BASENAME=$(basename "${FILE%.*}")
        EXT_LOWER=$(echo "${FILE##*.}" | tr '[:upper:]' '[:lower:]')
        
        # 出力ファイル名（重複時は連番）
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
            echo "# PDF解析中: $BASENAME"
            # ページ数を数字のみで抽出（環境依存の空白対策）
            PAGES=$(pdfinfo "$FILE" 2>/dev/null | grep "Pages:" | grep -oE '[0-9]+')
            
            if [[ -z "$PAGES" ]]; then
                REPORT_LIST+="[失敗] $BASENAME (PDF解析不能)\n"
                continue
            elif [ "$PAGES" -ne 1 ]; then
                REPORT_LIST+="[スキップ] $BASENAME (多ページPDF: ${PAGES}P)\n"
                continue
            else
                # 1ページのみの場合：一時ファイル作成
                # pdftoppmの仕様に合わせ、出力ベース名とフルパスを分離
                TEMP_BASE="/tmp/${BASENAME}_pdf_$(date +%s)"
                pdftoppm -f 1 -l 1 -singlefile -png -r 300 "$FILE" "$TEMP_
