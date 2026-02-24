#!/bin/bash

###############################################################################
# Script Name: WebP Batch Analyzer for Nemo
# Version:     1.2.0
# Description: 選択された複数のWebPファイルを一括解析し、表形式で一覧表示します。
#              Nemoのコンテキストメニューから複数のファイルを右クリックして実行可能です。
# Author:      Gemini Assistant
###############################################################################

# --- 1. 必要なパッケージのチェック ---
REQUIRED_PKGS=("webpinfo" "zenity" "bc")
for pkg in "${REQUIRED_PKGS[@]}"; do
    if ! command -v "$pkg" &> /dev/null; then
        zenity --error --text="エラー: '$pkg' がインストールされていません。\nsudo apt install webp zenity bc を実行してください。"
        exit 1
    fi
done

# --- 2. ファイルリストの取得 ---
# Nemoから渡されたすべてのファイルパスを配列に格納
IFS=$'\n' read -rd '' -a FILE_PATHS <<< "$NEMO_SCRIPT_SELECTED_FILE_PATHS"

if [ ${#FILE_PATHS[@]} -eq 0 ]; then
    zenity --error --text="ファイルが選択されていません。"
    exit 1
fi

# --- 3. 解析ループ ---
REPORT_DATA=()

# プログレスバーの準備
(
COUNT=0
TOTAL=${#FILE_PATHS[@]}

for FILE in "${FILE_PATHS[@]}"; do
    # 進捗計算
    COUNT=$((COUNT + 1))
    PERCENT=$((COUNT * 100 / TOTAL))
    echo "$PERCENT"
    echo "# 解析中 ($COUNT/$TOTAL): $(basename "$FILE")..."

    # WebPチェック
    if [[ ! "$FILE" =~ \.[wW][eE][bB][pP]$ ]]; then
        REPORT_DATA+=("$(basename "$FILE")" "ERROR" "-" "-" "Not a WebP")
        continue
    fi

    # webpinfoからデータ抽出
    INFO=$(webpinfo "$FILE" 2>/dev/null)
    WIDTH=$(echo "$INFO" | grep "Width:" | head -n 1 | awk '{print $2}')
    HEIGHT=$(echo "$INFO" | grep "Height:" | head -n 1 | awk '{print $2}')
    FORMAT=$(echo "$INFO" | grep "Format:" | head -n 1 | awk '{print $2}')
    FILE_SIZE=$(wc -c < "$FILE")

    if [ -z "$WIDTH" ]; then
        REPORT_DATA+=("$(basename "$FILE")" "Failed" "-" "-" "Invalid Data")
        continue
    fi

    # 密度（bpp）計算
    TOTAL_PIXELS=$((WIDTH * HEIGHT))
    BPP=$(echo "scale=2; ($FILE_SIZE * 8) / $TOTAL_PIXELS" | bc)
    
    # 圧縮レベルの判定
    if (( $(echo "$BPP < 0.5" | bc -l) )); then STRENGTH="高 (High)";
    elif (( $(echo "$BPP < 1.5" | bc -l) )); then STRENGTH="中 (Med)";
    else STRENGTH="低 (Low/Lossless)"; fi

    # 表に追加するデータを格納（列順: ファイル名, 形式, 解像度, 密度, 圧縮度）
    REPORT_DATA+=("$(basename "$FILE")")
    REPORT_DATA+=("$FORMAT")
    REPORT_DATA+=("${WIDTH}x${HEIGHT}")
    REPORT_DATA+=("$BPP")
    REPORT_DATA+=("$STRENGTH")
done

# --- 4. 結果を表形式で表示 ---
zenity --list \
    --title="WebP 一括解析レポート v1.2.0" \
    --width=800 --height=400 \
    --column="ファイル名" \
    --column="形式" \
    --column="解像度" \
    --column="密度(bpp)" \
    --column="圧縮強度" \
    "${REPORT_DATA[@]}"

) | zenity --progress --title="解析中" --text="ファイルをスキャンしています..." --auto-close --nostretch

exit 0
