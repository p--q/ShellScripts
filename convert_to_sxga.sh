#!/bin/bash

# ==============================================================================
# Script Name: convert_to_sxga.sh
# Version:     3.9 (Reliable Progress Bar)
# Updated:     2026-02-23
#
# [解説]
# - 進捗バーを確実に出すため、名前付きパイプ(FIFO)を利用した通信方式を採用。
# - レポート生成、サイズ比較、1ページPDF判定などの機能はすべて継承。
# ==============================================================================

if ! command -v zenity &> /dev/null; then
    exit 1
fi

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

# --- 進捗ダイアログの準備 ---
# 名前付きパイプを作成して、進捗バーをバックグラウンドで起動
PIPE=$(mktemp -u)
mkfifo "$PIPE"
zenity --progress --title="SXGA変換" --text="準備中..." --auto-close --percentage=0 < "$PIPE" &
Z_PID=$!
exec 3> "$PIPE" # ファイル記述子3に進捗バーへの経路を割り当て

TMP_REPORT=$(mktemp)
TOTAL=$#
COUNT=0

[ -n "$1" ] && cd "$(dirname "$1")" 2>/dev/null

for FILE in "$@"; do
    [ ! -f "$FILE" ] && continue
    
    COUNT=$((COUNT + 1))
    PERCENT=$((COUNT * 100 / TOTAL))
    
    # 進捗バーへの出力 (記述子3へ送る)
    echo "$PERCENT" >&3
    echo "# 処理中: $(basename "$FILE") ($COUNT/$TOTAL)" >&3

    ABS_FILE=$(realpath "$FILE")
    DIR=$(dirname "$ABS_FILE")
    BASENAME=$(basename "${ABS_FILE%.*}")
    EXT_LOWER=$(echo "${ABS_FILE##*.}" | tr '[:upper:]' '[:lower:]')
    OUT_FILE="$DIR/${BASENAME}.webp"

    OLD_SIZE_RAW=$(stat -c%s "$ABS_FILE" 2>/dev/null || echo 0)
    OLD_SIZE_HUMAN=$(format_size "$OLD_SIZE_RAW")

    if [ -f "$OUT_FILE" ]; then
        I=1
        while [ -f "$DIR/${BASENAME}_$I.webp" ]; do I=$((I+1)); done
        OUT_FILE="$DIR/${BASENAME}_$I.webp"
    fi

    # --- PDF処理 ---
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
                echo "[失敗] $BASENAME (PDF画像化失敗)" >> "$TMP_REPORT"
                continue
            fi
        else
            echo "[スキップ] $BASENAME (複数ページ不可: ${PAGES}P)" >> "$TMP_REPORT"
            continue
        fi
    fi

    # --- 画像変換 ---
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
        echo "[$STATUS] $BASENAME"$'\n'"    └ $NEW_DIM | $OLD_SIZE_HUMAN -> $NEW_SIZE_HUMAN" >> "$TMP_REPORT"
    else
        echo "[失敗] $BASENAME (解析不能)" >> "$TMP_REPORT"
    fi

    [ "$IS_PDF_TMP" = true ] && rm -f "$PROC_FILE"
done

# --- 後片付け ---
exec 3>&-      # 進捗バーへの接続を閉じる
rm -f "$PIPE"   # パイプを削除

# 全処理終了後にレポートを表示
if [ -f "$TMP_REPORT" ]; then
    zenity --text-info --title="変換完了 (v3.9)" --width=750 --height=500 --font="Monospace 10" < "$TMP_REPORT"
    rm -f "$TMP_REPORT"
fi
