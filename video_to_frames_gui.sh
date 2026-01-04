#!/bin/bash

################################################################################
# Script Name:  video_to_frames_final.sh
# Description:  抽出間隔をボタンで選び、1つのフォルダに連番で保存
# Version:      1.7.0
################################################################################

echo "===================================================="
echo "   Video Frame Extractor Ver 1.7.0"
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

echo "読み込み元: $SOURCE_DIR"
echo "保存先    : $SAVE_BASE"
echo "抽出間隔  : $INTERVAL 秒ごと"

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

    # シンプルな連番形式で出力
    # %03d は 001, 002... という意味です
    ffmpeg -i "$video" -vf "fps=1/$INTERVAL" -q:v 2 \
        "$SAVE_BASE/${FILE_NAME_BASE}_%03d.jpg" -loglevel warning

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
