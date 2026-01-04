#!/bin/bash

################################################################################
# Script Name:  video_to_frames_clean.sh
# Description:  抽出間隔をボタンで選び、警告を抑制して1つのフォルダに保存
# Version:      1.8.0
################################################################################

echo "===================================================="
echo "   Video Frame Extractor Ver 1.8.0"
echo "===================================================="

# 1. 動画が入っているフォルダを選択
SOURCE_DIR=$(zenity --file-selection --directory --title="1. 動画が入っているフォルダを選択してください")
[ -z "$SOURCE_DIR" ] && exit 0

# 2. 保存先のフォルダを選択
SAVE_BASE=$(zenity --file-selection --directory --title="2. 保存先のフォルダを選択してください" --filename="$HOME/ピクチャ/")
[ -z "$SAVE_BASE" ] && exit 0

# 3. 抽出間隔を選択
INTERVAL_CHOICE=$(zenity --list --radiolist --title="3. 抽出間隔の設定" \
    --text="抽出する間隔を選択してください" \
    --column="選択" --column="間隔（秒）" \
    FALSE "10" \
    FALSE "30" \
    TRUE "60" \
    FALSE "120" \
    FALSE "手入力（カスタム）")

[ -z "$INTERVAL_CHOICE" ] && exit 0

if [ "$INTERVAL_CHOICE" = "手入力（カスタム）" ]; then
    INTERVAL=$(zenity --scale --title="カスタム間隔" --text="秒数を指定してください" --value=60 --min-value=1 --max-value=3600 --step=1)
    [ -z "$INTERVAL" ] && exit 0
else
    INTERVAL=$INTERVAL_CHOICE
fi

# ffmpegチェック
if ! command -v ffmpeg &> /dev/null; then
    zenity --error --text="ffmpeg がインストールされていません。"
    exit 1
fi

# 動画ファイルの処理
cd "$SOURCE_DIR" || exit
shopt -s nocaseglob
found=false

for video in *.{mp4,ts,mkv,avi,wmv}; do
    if [[ ! -e "$video" ]]; then
        continue
    fi
    found=true

    echo "----------------------------------------------------"
    echo "処理中: $video"

    FILE_NAME_BASE="${video%.*}"

    # 修正ポイント: 
    # -pix_fmt yuvj420p を追加（JPEGに適したフルレンジのピクセル形式を明示）
    # これにより "deprecated pixel format" 警告が抑制されます
    ffmpeg -i "$video" -vf "fps=1/$INTERVAL" -pix_fmt yuvj420p -q:v 2 \
        "$SAVE_BASE/${FILE_NAME_BASE}_%03d.jpg" -loglevel error

    echo "完了: $video"
done

if [ "$found" = false ]; then
    zenity --info --text="対象ファイルが見つかりませんでした。"
else
    notify-send "処理完了" "すべての画像の保存が完了しました。"
fi

echo "===================================================="
echo "すべての処理が終了しました。"
echo "Enterキーを押すとこのウィンドウを閉じます。"
echo "===================================================="

read
