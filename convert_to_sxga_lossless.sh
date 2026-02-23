#!/bin/bash

# ==============================================================================
# Script Name: convert_to_sxga_lossless.sh
# Version:     2.5 (Hybrid Compression - Stable)
# Updated:     2026-02-23
# Description: 拡大時はLossless(高画質)、維持時はLossy(軽量)で変換。
#              余計な加工をせず、素材の画質を尊重する設定です。
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

        # 共通背景処理（白背景で透過対策）
        COMMON_OPTS="-background white -alpha remove -alpha off"

        # --- 判定ロジック ---
        if [ "$W" -ge 1280 ] || [ "$H" -ge 1024 ]; then
            # 【サイズ維持ルート】
            # 元の大きさを活かし、Lossy(Quality 90)でJPGより軽量化
            $CONVERT "$FILE" $COMMON_OPTS -quality 90 "$OUT_FILE"
            STATUS="維持(Lossy)"
        else
            # 【拡大ルート】
            # 標準的なLanczosフィルタで丁寧に拡大し、Losslessで劣化を防ぐ
            $CONVERT "$FILE" $COMMON_OPTS -filter Lanczos -resize "1280x1024" -define webp:lossless=true "$OUT_FILE"
            STATUS="拡大(Lossless)"
        fi

        # 最終的な結果の確認
        NEW_SIZE=$($IDENTIFY -ping -format "%wx%h" "$OUT_FILE" 2>/dev/null)
        REPORT_LIST+="[$STATUS] $BASENAME -> $(basename "$OUT_FILE") (${W}x${H} -> $NEW_SIZE)\n"
    done

    # 最終レポート表示
    echo -e "$REPORT_LIST" | zenity --text-info \
        --title="変換完了 (v2.5 安定版)" \
        --width=750 --height=450 \
        --ok-label="閉じる" \
        --font="Monospace 10"

) | zenity --progress --title="SXGA変換" --text="処理中..." --auto-close --percentage=0
