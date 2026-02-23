#!/bin/bash

# ==============================================================================
# Script Name: convert_to_sxga.sh
# Version:     4.1 (Full Dependency Check & Simple Logic)
# Updated:     2026-02-23
#
# [解説]
# 1. 動作に必要なパッケージ(ImageMagick, Poppler, Zenity)を冒頭で厳格にチェック。
# 2. 画像および1ページのみのPDFを「SXGA（1280x1024）」基準で変換。
# 3. 変換前後のサイズ比較を表示。複数ページPDFは理由を添えてスキップ。
# 4. 処理の確実性を優先し、プログレスバーを排したシンプル構造。
# ==============================================================================

# --- 1. 依存パッケージのチェック ---
MISSING_TOOLS=""
# ImageMagick (magick または convert)
if ! command -v magick &> /dev/null && ! command -v convert &> /dev/null; then
    MISSING_TOOLS+="・ImageMagick (magick または convert)\n"
fi
# Poppler (pdftoppm, pdfinfo)
if ! command -v pdftoppm &> /dev/null; then
    MISSING_TOOLS+="・poppler-utils (pdftoppm)\n"
fi
if ! command -v pdfinfo &> /dev/null; then
    MISSING_TOOLS+="・poppler-utils (pdfinfo)\n"
fi
# Zenity
if ! command -v zenity &> /dev/null; then
    echo "Error: zenity is not installed."
    exit 1
fi

# 不足ツールがあればダイアログを出して終了
if [ -n "$MISSING_TOOLS" ]; then
    zenity --error --title="依存エラー" --text="以下のパッケージが必要です。インストールしてください:\n\n$MISSING_TOOLS\n【コマンド例】\nsudo apt install imagemagick poppler-utils"
    exit 1
fi

# --- 2. 各種設定 ---
format_size() {
    local size=$1
    if [ "$size" -lt 1024 ]; then
        echo "${size}B"
    elif [ "$size" -lt 1048576 ]; then
        echo "$((size / 1024)).$(((size % 1024) * 10 / 1024))KB"
    else
        echo "$((size / 1048576)).$(((size % 1048576) * 10 / 1048576))MB"
    fi
}

REPORT_LIST=""
TOTAL=$#
COUNT=0

# コマンド判別
CMD=$(command -v magick || command -v convert)
ID_CMD=$(command -v identify || echo "magick identify")

# 実行場所の解決
[ -n "$1" ] && cd "$(dirname "$1")" 2>/dev/null

# --- 3. 処理ループ ---
for FILE in "$@"; do
    [ ! -f "$FILE" ] && continue
    
    COUNT=$((COUNT + 1))
    ABS_FILE=$(realpath "$FILE")
    DIR=$(dirname "$ABS_FILE")
    BASENAME=$(basename "${ABS_FILE%.*}")
    EXT_LOWER=$(echo "${ABS_FILE##*.}" | tr '[:upper:]' '[:lower:]')
    OUT_FILE="$DIR/${BASENAME}.webp"

    # 元のサイズ
    OLD_SIZE_RAW=$(stat -c%s "$ABS_FILE" 2>/dev/null || echo 0)
    OLD_SIZE_HUMAN=$(format_size "$OLD_SIZE_RAW")

    # 同名ファイル回避
    if [ -f "$OUT_FILE" ]; then
        I=1
        while [ -f "$DIR/${BASENAME}_$I.webp" ]; do I=$((I+1)); done
        OUT_FILE="$DIR/${BASENAME}_$I.webp"
    fi

    # PDF処理
    PROC_FILE="$ABS_FILE"
    IS_PDF_TMP=false
    if [ "$EXT_LOWER" = "pdf" ]; then
        PAGES=$(pdfinfo "$ABS_FILE" 2>/dev/null | grep "Pages:" | grep -oE '[0-9]+')
        if [ "${PAGES:-0}" -eq 1 ]; then
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
            REPORT_LIST+="[スキップ] $BASENAME (複数ページ不可: ${PAGES}P)\n"
            continue
        fi
    fi

    # 画像変換
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
        REPORT_LIST+="[失敗] $BASENAME (解析不能)\n"
    fi

    [ "$IS_PDF_TMP" = true ] && rm -f "$PROC_FILE"
done

# --- 4. 結果表示 ---
if [ -n "$REPORT_LIST" ]; then
    echo -e "$REPORT_LIST" | zenity --text-info \
        --title="変換完了 (v4.1)" \
        --width=750 --height=550 \
        --ok-label="閉じる" \
        --font="Monospace 10"
else
    zenity --info --title="完了" --text="処理対象のファイルがありませんでした。" --width=300
fi
