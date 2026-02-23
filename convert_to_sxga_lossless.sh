#!/bin/bash

# ==============================================================================
# Script Name: convert_to_sxga_lossless.sh
# Version:     2.3 (Refined)
# Updated:     2026-02-23
# Description: 1280x1024以上の辺があれば維持、なければ拡大。
#              WebP Lossless変換 + 背景白埋め。
# ==============================================================================

# コマンドのセットアップ
if command -v magick &> /dev/null; then
    CONVERT="magick"
    IDENTIFY="magick identify"
else
    CONVERT="convert"
    IDENTIFY="identify"
fi

# ログ用変数
REPORT_LIST=""

(
    TOTAL=$#
    COUNT=0
    for FILE in "$@"; do
        [ ! -f "$FILE" ] && continue

        # 出力ファイル名の生成
        DIR=$(dirname "$FILE")
        BASENAME=$(basename "${FILE%.*}")
        OUT_FILE="$DIR/${BASENAME}_oversxga.webp"

        # 同名回避（連番付与）
        I=1
        while [ -f "$OUT_FILE" ]; do
            OUT_FILE="$DIR/${BASENAME}_oversxga_$(printf "%02d" $I).webp"
            I=$((I + 1))
        done

        # サイズ取得（pingでヘッダーのみ読み取り）
        SIZE_INFO=$($IDENTIFY -ping -format "%w %h" "$FILE" 2>/dev/null)
        read -r W H <<< "$SIZE_INFO"

        # 取得失敗時のスキップ処理
        if [[ ! "$W" =~ ^[0-9]+$ ]]; then
             REPORT_LIST+="[失敗] $FILE (サイズ取得不能)\n"
             continue
        fi

        COUNT=$((COUNT + 1))
        PERCENT=$((COUNT * 100 / TOTAL))
        echo "$PERCENT"
        echo "# 処理中: $BASENAME (${W}x${H})"

        # 共通の変換オプション
        OPTS="-background white -alpha remove -alpha off -define webp:lossless=true"

        # 判定：どちらかの辺がSXGA以上ならサイズ維持
        if [ "$W" -ge 1280 ] || [ "$H" -ge 1024 ]; then
            $CONVERT "$FILE" $OPTS "$OUT_FILE"
            STATUS="維持"
        else
            # 両方の辺が小さい場合は拡大
            $CONVERT "$FILE" $OPTS -filter Lanczos -resize "1280x1024" "$OUT_FILE"
            STATUS="拡大"
        fi

        # 結果をリストに追加
        NEW_SIZE=$($IDENTIFY -ping -format "%wx%h" "$OUT_FILE" 2>/dev/null)
        REPORT_LIST+="[$STATUS] $BASENAME: ${W}x${H} -> $NEW_SIZE\n"
    done

    # 最終レポート表示
    echo -e "$REPORT_LIST" | zenity --text-info \
        --title="変換完了 (v2.3)" \
        --width=600 --height=400 \
        --ok-label="閉じる" \
        --font="Monospace 10"

) | zenity --progress --title="SXGA変換" --text="準備中..." --auto-close --percentage=0
