#!/bin/bash

# ==============================================================================
# Script Name: convert_to_xga_lossless.sh
# Description: 画質劣化ゼロ(WebP Lossless)でXGAサイズへ変換。
#              ファイル名末尾に _xga を付与。透明背景は白で塗りつぶし。
# Version:     1.3.0
# ==============================================================================

# --- 1. 依存関係チェック ---
if command -v magick &> /dev/null; then
    IMG_TOOL="magick"
elif command -v convert &> /dev/null; then
    IMG_TOOL="convert"
else
    zenity --error --text="ImageMagickがインストールされていません。"
    exit 1
fi

# --- 2. 引数チェック ---
if [ "$#" -eq 0 ]; then
    zenity --info --title="使い方" --text="画像を右クリックメニューから実行してください。"
    exit 0
fi

# --- 3. メイン処理 ---
(
    COUNT=0
    TOTAL=$#
    for FILE in "$@"; do
        if [ ! -f "$FILE" ]; then continue; fi

        DIR=$(dirname "$FILE")
        FILENAME=$(basename "$FILE")
        BASENAME="${FILENAME%.*}"
        
        # 出力ファイル名の決定（末尾に _xga を付与）
        OUT_FILE="$DIR/${BASENAME}_xga.webp"
        
        # 同名回避ロジック（_xga_01, _xga_02...）
        if [ -f "$OUT_FILE" ]; then
            I=1
            while [ -f "$DIR/${BASENAME}_xga_$(printf "%02d" $I).webp" ]; do
                I=$((I + 1))
            done
            OUT_FILE="$DIR/${BASENAME}_xga_$(printf "%02d" $I).webp"
        fi

        COUNT=$((COUNT + 1))
        PERCENT=$((COUNT * 100 / TOTAL))
        echo "$PERCENT"
        echo "# 処理中: $FILENAME"

        # --- 変換実行 ---
        $IMG_TOOL "$FILE" \
            -background white -alpha remove -alpha off \
            -filter Lanczos \
            -resize 1024x768 \
            -define webp:lossless=true \
            "$OUT_FILE"
    done
) | zenity --progress --title="高画質ロスレス変換" --text="準備中..." --auto-close --percentage=0

# --- 4. 完了通知 ---
MSG=$(echo -e "処理が完了しました！\nファイル名の末尾に _xga を追加しました。\n形式: WebP Lossless")
zenity --info --title="完了" --text="$MSG" --timeout=3
