#!/bin/bash

# ==============================================================================
# Script Name: convert_to_xga_pro.sh
# Description: 文字の滲みを抑えてXGAへ拡大・変換（WebP形式）。
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

# --- 2. メイン処理 ---
(
    COUNT=0
    TOTAL=$#
    for FILE in "$@"; do
        if [ ! -f "$FILE" ]; then continue; fi

        DIR=$(dirname "$FILE")
        FILENAME=$(basename "$FILE")
        BASENAME="${FILENAME%.*}"
        
        # 出力ファイル（WebPに変更）
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
        echo "# 処理中: $FILENAME"

        # --- 変換のポイント ---
        # -filter point: ニアレストネイバー法を使い、拡大時のボケを防ぐ（文字がクッキリします）
        # -define webp:lossless=true: 画質を1ミリも落としたくない場合はこれ（サイズは増えます）
        $IMG_TOOL "$FILE" \
            -filter point \
            -resize 1024x768 \
            -background white -alpha remove -alpha off \
            -quality 90 \
            "$OUT_FILE"
    done
) | zenity --progress --title="画像変換 (高画質WebP)" --text="準備中..." --auto-close --percentage=0

MSG=$(echo -e "処理が完了しました！\n文字の滲みを抑えてWebPで保存しました。")
zenity --info --title="完了" --text="$MSG" --timeout=3
