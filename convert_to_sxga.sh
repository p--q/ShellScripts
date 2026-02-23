#!/bin/bash

# --- 依存チェック ---
if ! command -v zenity &> /dev/null; then
    echo "zenity is not installed"
    exit 1
fi

REPORT_LIST=""

# 処理開始
(
    TOTAL=$#
    COUNT=0
    
    for FILE in "$@"; do
        [ ! -f "$FILE" ] && continue
        
        ABS_FILE=$(realpath "$FILE")
        DIR=$(dirname "$ABS_FILE")
        BASENAME=$(basename "${ABS_FILE%.*}")
        EXT_LOWER=$(echo "${ABS_FILE##*.}" | tr '[:upper:]' '[:lower:]')
        OUT_FILE="$DIR/${BASENAME}.webp"

        # 重複回避
        if [ -f "$OUT_FILE" ]; then
            I=1
            while [ -f "$DIR/${BASENAME}_$I.webp" ]; do I=$((I+1)); done
            OUT_FILE="$DIR/${BASENAME}_$I.webp"
        fi

        COUNT=$((COUNT + 1))
        echo "$((COUNT * 100 / TOTAL))"
        echo "# 処理中: $BASENAME"

        # --- PDF処理の簡略化 ---
        if [ "$EXT_LOWER" = "pdf" ]; then
            # ページ数取得 (ここがエラーの源になりやすいため慎重に)
            PAGES_STR=$(pdfinfo "$ABS_FILE" 2>/dev/null | grep "Pages:" | grep -oE '[0-9]+')
            PAGES=${PAGES_STR:-0} # 空なら0にする

            if [ "$PAGES" -eq 1 ]; then
                TEMP_PNG="/tmp/pdf_tmp_$(date +%s%N).png"
                # pdftoppmの出力を確実にキャッチ
                pdftoppm -f 1 -l 1 -singlefile -png -r 300 "$ABS_FILE" "${TEMP_PNG%.png}"
                if [ -f "$TEMP_PNG" ]; then
                    PROC_FILE="$TEMP_PNG"
                    IS_PDF_TMP=true
                else
                    REPORT_LIST+="[失敗] $BASENAME (画像化失敗)\n"
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

        # --- 画像変換 (ImageMagick) ---
        # convertかmagickか自動判別
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
            REPORT_LIST+="[$STATUS] $BASENAME\n"
        else
            REPORT_LIST+="[失敗] $BASENAME (解析不能)\n"
        fi

        [ "$IS_PDF_TMP" = true ] && rm -f "$PROC_FILE"
    done

    # レポート表示
    echo -e "$REPORT_LIST" | zenity --text-info --title="完了" --width=600 --height=400
) | zenity --progress --title="SXGA変換" --auto-close
