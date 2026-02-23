#!/bin/bash

# ==============================================================================
# Script Name: convert_to_sxga.sh
# Version:     3.0 (Lossy Unified Edition)
# Updated:     2026-02-23
# Description: すべての出力を Lossy WebP に統一。
#              1280x1024未満は拡大、それ以上は維持。
#              1ページのみのPDFにも対応。
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
            PAGES=$(pdfinfo "$FILE" 2>/dev/null | grep "Pages:" | awk '{print $2}')
            
            if [ "$PAGES" -eq 1 ]; then
                TEMP_IMAGE="/tmp/${BASENAME}_pdf_tmp.png"
                pdftoppm -f 1 -l 1 -singlefile -png -r 300 "$FILE" "/tmp/${BASENAME}_pdf_tmp"
                PROC_FILE="$TEMP_IMAGE"
                IS_PDF_TMP=true
            else
                REPORT_LIST+="[スキップ] $BASENAME (多ページPDF: ${PAGES}P)\n"
                continue
            fi
        else
            PROC_FILE="$FILE"
            IS_PDF_TMP=false
        fi

        # --- 画像サイズ取得と判定 ---
        echo "# 処理中: $BASENAME"
        SIZE_INFO=$($IDENTIFY -ping -format "%w %h" "$PROC_FILE" 2>/dev/null)
        read -r W H <<< "$SIZE_INFO"

        if [[ ! "$W" =~ ^[0-9]+$ ]]; then
             REPORT_LIST+="[失敗] $BASENAME (解析不能)\n"
             [ "$IS_PDF_TMP" = true ] && rm "$PROC_FILE"
             continue
        fi

        # 共通オプション（白背景＋高品質Lossy）
        # すべてLossyに統一するため、-quality 90 を常に使用
        OPTS="-background white -alpha remove -alpha off -quality 90"

        if [ "$W" -ge 1280 ] || [ "$H" -ge 1024 ]; then
            # 【サイズ維持ルート】
            $CONVERT "$PROC_FILE" $OPTS "$OUT_FILE"
            STATUS="維持"
        else
            # 【拡大ルート】
            # イラスト・図解向けにバランスの良い Lanczos を採用
            $CONVERT "$PROC_FILE" $OPTS -filter Lanczos -resize "1280x1024" "$OUT_FILE"
            STATUS="拡大"
        fi

        # レポート用情報の整理
        [ "$EXT_LOWER" = "pdf" ] && STATUS="PDF->$STATUS"
        NEW_SIZE=$($IDENTIFY -ping -format "%wx%h" "$OUT_FILE" 2>/dev/null)
        REPORT_LIST+="[$STATUS] $BASENAME -> $(basename "$OUT_FILE") (${W}x${H} -> $NEW_SIZE)\n"

        # 一時ファイルの削除
        [ "$IS_PDF_TMP" = true ] && rm "$PROC_FILE"
    done

    # 最終レポート表示
    echo -e "$REPORT_LIST" | zenity --text-info \
        --title="変換完了 (v3.0 Lossy版)" \
        --width=750 --height=450 --ok-label="閉じる" --font="Monospace 10"

) | zenity --progress --title="SXGA変換" --text="開始中..." --auto-close --percentage=0
