#!/bin/bash

###############################################################################
# Script Name: WebP Analyzer for Nemo
# Version:     1.1.0
# Description: WebPファイルの圧縮形式（Lossy/Lossless）とデータ密度（bpp）を判定し、
#              結果をGUIダイアログで表示します。
# Author:      Gemini Assistant
###############################################################################

# --- 1. 必要なパッケージのチェック ---
REQUIRED_PKGS=("webpinfo" "zenity" "bc")
MISSING_PKGS=()

for pkg in "${REQUIRED_PKGS[@]}"; do
    if ! command -v "$pkg" &> /dev/null; then
        MISSING_PKGS+=("$pkg")
    fi
done

if [ ${#MISSING_PKGS[@]} -ne 0 ]; then
    zenity --error --title="エラー: パッケージ不足" \
        --text="以下のパッケージがインストールされていません:\n\n<b>${MISSING_PKGS[*]}</b>\n\n端末で 'sudo apt install webp zenity bc' を実行してください。"
    exit 1
fi

# --- 2. ターゲットファイルの取得 ---
# Nemoの環境変数から選択されたファイルのパスを取得
FILE=$(echo "$NEMO_SCRIPT_SELECTED_FILE_PATHS" | head -n 1)

# 環境変数が空（単体実行など）の場合は引数から取得
if [ -z "$FILE" ]; then
    FILE=$1
fi

# ファイルが選択されていない場合の処理
if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
    zenity --error --text="解析するWebPファイルが見つかりません。"
    exit 1
fi

# 拡張子チェック
if [[ ! "$FILE" =~ \.[wW][eE][bB][pP]$ ]]; then
    zenity --warning --text="選択されたファイルはWebP形式ではない可能性があります。\nファイル名: $(basename "$FILE")"
    # 続行するかはユーザーに任せる（強制終了せず解析を試みる）
fi

# --- 3. WebP情報の解析 ---
INFO=$(webpinfo "$FILE" 2>/dev/null)
WIDTH=$(echo "$INFO" | grep "Width:" | head -n 1 | awk '{print $2}')
HEIGHT=$(echo "$INFO" | grep "Height:" | head -n 1 | awk '{print $2}')
FORMAT=$(echo "$INFO" | grep "Format:" | head -n 1 | awk '{print $2}')
FILE_SIZE=$(wc -c < "$FILE")

# 解析失敗時のガード
if [ -z "$WIDTH" ] || [ -z "$FORMAT" ]; then
    zenity --error --text="WebPデータの解析に失敗しました。ファイルが破損しているか、対応していない形式です。"
    exit 1
fi

# --- 4. 圧縮率（bpp）の計算 ---
TOTAL_PIXELS=$((WIDTH * HEIGHT))
# bits per pixel = (ファイルサイズ[byte] * 8ビット) / 総ピクセル数
BPP=$(echo "scale=4; ($FILE_SIZE * 8) / $TOTAL_PIXELS" | bc)

# 圧縮強度の判定（bppに基づく目安）
if (( $(echo "$BPP < 0.5" | bc -l) )); then
    STRENGTH="高 (かなり強く圧縮されています)"
elif (( $(echo "$BPP < 1.5" | bc -l) )); then
    STRENGTH="中 (標準的な圧縮率です)"
else
    STRENGTH="低 (高品質、または可逆圧縮です)"
fi

# --- 5. 結果表示 ---
zenity --info \
    --title="WebP 解析結果 - v1.1.0" \
    --width=450 \
    --timeout=30 \
    --text="<span foreground='blue' size='large'><b>画像解析レポート</b></span>\n\n\
<b>ファイル名:</b>  $(basename "$FILE")\n\
<b>圧縮形式:</b>  <span color='#d35400'>$FORMAT</span>\n\
<b>キャンバス:</b>  ${WIDTH} x ${HEIGHT} px\n\
<b>データ密度:</b>  $BPP bpp (bits per pixel)\n\
--------------------------------------------------\n\
<b>圧縮の強さ:</b>  $STRENGTH"

exit 0
