#!/bin/bash

# --- 依存関係チェック等は省略せず全体を記載 ---
if command -v magick &> /dev/null; then IMG_TOOL="magick"; else IMG_TOOL="convert"; fi

(
    COUNT=0
    TOTAL=$#
    for FILE in "$@"; do
        if [ ! -f "$FILE" ]; then continue; fi

        DIR=$(dirname "$FILE")
        FILENAME=$(basename "$FILE")
        BASENAME="${FILENAME%.*}"
        OUT_FILE="$DIR/${BASENAME}_xga.webp" # 識別しやすくするため_xgaを付与

        # --- 図表・文字を綺麗に拡大する魔法の設定 ---
        # 1. -filter Mitchell: ぼやけとカクカクの中間を狙う高品質な補完
        # 2. -distort Resize: 単なる-resizeより計算が精密
        # 3. -unsharp: 拡大でボケた輪郭を「文字」として認識できるレベルまで引き締める
        $IMG_TOOL "$FILE" \
            -filter Mitchell \
            -distort Resize 1024x768 \
            -unsharp 1.5x1+0.7+0.02 \
            -background white -alpha remove -alpha off \
            -quality 95 \
            "$OUT_FILE"

        COUNT=$((COUNT + 1))
        PERCENT=$((COUNT * 100 / TOTAL))
        echo "$PERCENT"
    done
) | zenity --progress --title="高精度変換" --auto-close

zenity --info --text="図表向け調整で変換しました。" --timeout=3
