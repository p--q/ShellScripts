#!/bin/bash

################################################################################
# Script Name:  video_to_frames_fast.sh
# Description:  高速シーク(-ss)を使用して、指定秒ごとにピンポイントで抽出
# Version:      1.9.0
################################################################################

echo "===================================================="
echo "   Video Frame Extractor Ver 1.9.0 (High Speed)"
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

# ツールチェック (ffprobeも必要になります)
if ! command -v ffmpeg &> /dev/null || ! command -v ffprobe &> /dev/null; then
    zenity --error --text="ffmpeg または ffprobe が見つかりません。"
    exit 1
fi

# 動画ファイルの処理
cd "$SOURCE_DIR" || exit
shopt -s nocaseglob
found=false

for video in *.{mp4,ts,mkv,avi,wmv}; do
    if [[ ! -e "$video" ]]; then continue; fi
    found=true

    echo "----------------------------------------------------"
    echo "高速処理開始: $video"

    FILE_NAME_BASE="${video%.*}"

    # 動画の総再生時間を取得（ffprobeを使用）
    duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$video")
    # 小数点を切り捨てて整数にする
    duration_int=${duration%.*}

    # 指定秒数ごとにジャンプして抽出
    count=1
    for (( s=0; s<duration_int; s+=INTERVAL )); do
        # -ss を -i の前に置くことで高速シークが有効になります
        # -frames:v 1 でその地点の1枚だけを取得
        ffmpeg -ss "$s" -i "$video" -frames:v 1 -pix_fmt yuvj420p -q:v 2 \
            "$SAVE_BASE/${FILE_NAME_BASE}_$(printf "%03d" $count).jpg" -loglevel error
        
        # 進捗をターミナルに表示
        echo -n "." 
        ((count++))
    done
    echo -e "\n完了: $video (計 $((count-1)) 枚)"
done

if [ "$found" = false ]; then
    zenity --info --text="対象ファイルが見つかりませんでした。"
else
    notify-send "処理完了" "高速抽出が完了しました。"
fi

echo "===================================================="
echo "すべての処理が終了しました。"
echo "Enterキーを押すとこのウィンドウを閉じます。"
echo "===================================================="

read
