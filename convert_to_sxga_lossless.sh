#!/bin/bash

# ==============================================================================
# Script Name: convert_to_sxga_lossless.sh
# Version:     2.6 (Diagram & Illustration Optimized)
# Updated:     2026-02-23
# Description: イラスト・文字入りの図に最適化したSXGA変換スクリプト。
#              拡大時はMitchellフィルタ+シャープネスで文字をクッキリさせ、
#              Lossless WebPで保存。維持時はLossy WebPで軽量化。
# ==============================================================================

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
        
        # 出力ファイル名（重複時は連番）
        OUT_FILE="$DIR/${BASENAME}.webp"
        if [ -f "$OUT_FILE" ]; then
            I=1
            while [ -f "$DIR/${BASENAME}_$(printf "%02d" $I).webp" ]; do
                I=$((I + 1))
            done
            OUT_FILE="$DIR/${BASENAME}_$(printf "%02d" $I).webp"
        fi

        # サイズ取得
        SIZE_INFO=$($IDENTIFY -ping -format "%w %h" "$FILE" 2>/dev/null)
        read -r W H <<< "$SIZE_INFO"

        if [[ ! "$W" =~ ^[0-9]+$ ]]; then
             REPORT_LIST+="[失敗] $BASENAME (サイズ取得不能)\n"
             continue
        fi

        COUNT=$((COUNT + 1))
        PERCENT=$((COUNT * 100 / TOTAL))
        echo "$PERCENT"
        echo "# 処理中: $BASENAME (${W}x${H})"

        # 共通背景処理（透過対策）
        COMMON_OPTS="-background white -alpha remove -alpha off"

        # --- 判定ロジック ---
        if [ "$W" -ge 1280 ] || [ "$H" -ge 1024 ]; then
            # 【サイズ維持ルート】
            # 元が十分大きいため、Lossy(Quality 90)で効率よく保存
            $CONVERT "$FILE" $COMMON_OPTS -quality 90 "$OUT_FILE"
            STATUS="維持(Lossy)"
        else
            # 【拡大ルート：イラスト・文字特化】
            # -filter Mitchell: 文字の縁に不自然な光輪（ハロー）が出にくい
            # -unsharp: 0x0.5+0.5+0.008 の微弱なシャープで文字の読みやすさを向上
            # -define webp:lossless=true: 拡大による劣化をこれ以上増やさない
            $CONVERT "$FILE" $COMMON_OPTS \
                -filter Mitchell -resize "1280x1024" \
                -unsharp 0x0.5+0.5+0.008 \
                -define webp:lossless=true "$OUT_FILE"
            STATUS="拡大(Lossless/Sharp)"
        fi

        # 最終的な結果の確認
        NEW_SIZE=$($IDENTIFY -ping -format "%wx%h" "$OUT_FILE" 2>/dev/null)
        REPORT_LIST+="[$STATUS] $BASENAME -> $(basename "$OUT_FILE") (${W}x${H} -> $NEW_SIZE)\n"
    done

    # 最終レポート表示
    echo -e "$REPORT_LIST" | zenity --text-info \
        --title="変換完了 (v2.6 イラスト・文字特化版)" \
        --width=750 --height=450 \
        --ok-label="閉じる" \
        --font="Monospace 10"

) | zenity --progress --title="SXGA変換" --text="処理中..." --auto-close --percentage=0
