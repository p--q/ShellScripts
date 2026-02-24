#!/bin/bash

###############################################################################
# Script Name: WebP Batch Analyzer for Nemo (Fixed)
# Version:     1.2.1
# Description: 選択された複数のWebPファイルを一括解析し、表形式で表示します。
#              結果表示に特化した閲覧モードです。
###############################################################################

# --- 1. 必要なパッケージのチェック ---
REQUIRED_PKGS=("webpinfo" "zenity" "bc")
for pkg in "${REQUIRED_PKGS[@]}"; do
    if ! command -v "$pkg" &> /dev/null; then
        zenity --error --text="エラー: '$pkg' がインストールされていません。"
        exit 1
    fi
done

# --- 2. ファイルリストの取得 ---
IFS=$'\n' read -rd '' -a FILE_PATHS <<< "$NEMO_SCRIPT_SELECTED_FILE_PATHS"

if [ ${#FILE_PATHS[@]} -eq 0 ]; then
    # Nemo経由でない場合のフォールバック（引数から取得）
    FILE_PATHS=("$@")
fi

if [ ${#FILE_PATHS[@]} -eq 0 ]; then
    zenity --error --text="ファイルが選択されていません。"
    exit 1
fi

# --- 3. 解析ループ ---
REPORT_DATA=()

# プログレスバーを表示しながら解析
(
COUNT=0
TOTAL=${#FILE_PATHS[@]}

for FILE in "${FILE_PATHS[@]}"; do
    COUNT=$((COUNT + 1))
    PERCENT=$((COUNT * 100 / TOTAL))
    echo "$PERCENT"
    echo "# 解析中 ($COUNT/$TOTAL): $(basename "$FILE")..."

    if [[ ! "$FILE" =~ \.[wW][eE][bB][pP]$ ]]; then
        REPORT_DATA+=("$(basename "$FILE")" "ERROR" "-" "-" "Not a WebP")
        continue
    fi

    INFO=$(webpinfo "$FILE" 2>/dev/null)
    WIDTH=$(echo "$INFO" | grep "Width:" | head -n 1 | awk '{print $2}')
    HEIGHT=$(echo "$INFO" | grep "Height:" | head -n 1 | awk '{print $2}')
    FORMAT=$(echo "$INFO" | grep "Format:" | head -n 1 | awk '{print $2}')
    FILE_SIZE=$(wc -c < "$FILE")

    if [ -z "$WIDTH" ]; then
        REPORT_DATA+=("$(basename "$FILE")" "Failed" "-" "-" "Invalid Data")
        continue
    fi

    TOTAL_PIXELS=$((WIDTH * HEIGHT))
    BPP=$(echo "scale=2; ($FILE_SIZE * 8) / $TOTAL_PIXELS" | bc)
    
    if (( $(echo "$BPP < 0.5" | bc -l) )); then STRENGTH="高 (High)";
    elif (( $(echo "$BPP < 1.5" | bc -l) )); then STRENGTH="中 (Med)";
    else STRENGTH="低 (Low/Lossless)"; fi

    REPORT_DATA+=("$(basename "$FILE")")
    REPORT_DATA+=("$FORMAT")
    REPORT_DATA+=("${WIDTH}x${HEIGHT}")
    REPORT_DATA+=("$BPP")
    REPORT_DATA+=("$STRENGTH")
done

# --- 4. 結果を一覧表で表示 ---
# --ok-label を「閉じる」に変更し、選択機能を無効化する工夫をしています
zenity --list \
    --title="WebP 一括解析レポート v1.2.1" \
    --width=850 --height=450 \
    --ok-label="閉じる" \
    --hide-header=false \
    --column="ファイル名" \
    --column="形式" \
    --column="解像度" \
    --column="密度(bpp)" \
    --column="圧縮強度" \
    "${REPORT_DATA[@]}" > /dev/null 2>&1 # 出力を捨てて終了する

) | zenity --progress --title="解析中" --text="ファイルをスキャンしています..." --auto-close --nostretch
