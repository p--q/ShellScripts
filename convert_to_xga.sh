#!/bin/bash

# ==============================================================================
# Script Name: convert_to_xga.sh
# Description: 画像の長辺をXGAサイズ(1024x768)にリサイズし、背景を白塗りしてJPG変換します。
#              ドラッグ&ドロップまたは引数での一括処理に対応しています。
# Version:     1.1.0
# Author:      Gemini Assistant
# ==============================================================================

# --- 1. 依存関係（パッケージ）チェック ---
MISSING_PKGS=()

# zenity (ダイアログ表示用) のチェック
if ! command -v zenity &> /dev/null; then
    echo "Error: 'zenity' がインストールされていません。'sudo apt install zenity' を実行してください。"
    exit 1
fi

# ImageMagick のチェック (magick または convert)
if command -v magick &> /dev/null; then
    IMG_TOOL="magick"
elif command -v convert &> /dev/null; then
    IMG_TOOL="convert"
else
    MISSING_PKGS+=("imagemagick")
fi

# 不足パッケージがある場合にGUIで通知
if [ ${#MISSING_PKGS[@]} -ne 0 ]; then
    zenity --error \
        --title="システムエラー: 依存関係不足" \
        --text="処理に必要なツール (${MISSING_PKGS[*]}) が見つかりません。\n\n端末で以下のコマンドを実行してインストールしてください：\n\n<b>sudo apt update && sudo apt install ${MISSING_PKGS[*]}</b>" \
        --width=400
    exit 1
fi

# --- 2. 引数チェック ---
if [ "$#" -eq 0 ]; then
    zenity --info --title="使い方" --text="画像をこのスクリプトにドラッグ＆ドロップするか、\n右クリックメニュー（Nemo Scripts）から実行してください。"
    exit 0
fi

# --- 3. メイン処理 ---
OUTPUT_DIR="converted_jpg"
mkdir -p "$OUTPUT_DIR"

# 処理中ダイアログを表示（プログレスバー）
(
    COUNT=0
    TOTAL=$#
    for FILE in "$@"; do
        if [ ! -f "$FILE" ]; then continue; fi

        FILENAME=$(basename "$FILE")
        BASENAME="${FILENAME%.*}"
        
        # パーセンテージ計算
        COUNT=$((COUNT + 1))
        PERCENT=$((COUNT * 100 / TOTAL))
        echo "$PERCENT"
        echo "# 処理中: $FILENAME ($COUNT/$TOTAL)"

        # ImageMagick 実行
        # -background white -alpha remove: 透明度を白に置換
        # -resize 1024x768: アスペクト比を維持しつつ長辺をXGAに
        $IMG_TOOL "$FILE" \
            -background white -alpha remove -alpha off \
            -resize 1024x768 \
            "$OUTPUT_DIR/${BASENAME}.jpg"
    done
) | zenity --progress --title="画像変換" --text="準備中..." --auto-close --percentage=0

# --- 4. 終了通知 ---
zenity --info \
    --title="完了" \
    --text="すべての処理が終了しました。\n出力先: <b>$OUTPUT_DIR/</b>" \
    --timeout=5
