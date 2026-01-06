#!/bin/bash

################################################################################
# Script Name:  video_to_frames_ultimate_silent.sh
# Description:  高速シーク時のエラー表示を完全に抑制し、進捗のみ表示
# Version:      2.1.0
################################################################################

echo "===================================================="
echo "   Video Frame Extractor Ver 2.1.0"
echo "===================================================="

# 1. フォルダ選択
SOURCE_DIR=$(zenity --file-selection --directory --title="1. 動画が入っているフォルダを選択してください")
[ -z "$SOURCE_DIR" ] && exit 0

SAVE_BASE=$(zenity --file-selection --directory --title="2. 保存先のフォルダを選択してください" --filename="$HOME/ピクチャ/")
[ -z "$SAVE_BASE" ] && exit 0

# 2. 間隔選択
INTERVAL_CHOICE=$(zenity --list --radiolist --title="3. 抽出間隔の設定" \
    --text="抽出する間隔を選択してください" \
    --column="選択" --column="間隔（秒）" \
    FALSE "10" FALSE "30" TRUE "60" FALSE "120" FALSE "手入力")

[ -z "$INTERVAL_CHOICE" ] && exit 0

if [ "$INTERVAL_CHOICE" = "手入力" ]; then
    INTERVAL=$(zenity --scale --title="カスタム間隔" --text="秒数指定" --value=60 --min-value=1 --max-value=3600)
    [ -z "$INTERVAL" ] && exit 0
else
    INTERVAL=$INTERVAL_CHOICE
fi

# ツールチェック
if ! command -v ffmpeg &> /dev/null; then
    zenity --error --text="ffmpeg が見つかりません。"
    exit 1
fi

cd "$SOURCE_DIR" || exit
shopt -s nocaseglob
found=false

for video in *.{mp4,ts,mkv,avi,wmv}; do
    if [[ ! -e "$video" ]]; then continue; fi
    found=true

    echo "----------------------------------------------------"
    echo "処理中: $video"

    FILE_NAME_BASE="${video%.*}"
    duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$video")
    duration_int=${duration%.*}

    count=1
    total_steps=$((duration_int / INTERVAL + 1))

    for (( s=0; s<duration_int; s+=INTERVAL )); do
        # --- 修正の要：ffmpegコマンドの組み立て ---
        # -loglevel quiet: ffmpeg自身のログを消す
        # -er 4: エラー耐性を最大にする（壊れたフレームも無視して進む）
        # 2>/dev/null: OSレベルで標準エラー出力を捨てる
        ffmpeg -loglevel quiet -er 4 -ss "$s" -i "$video" \
            -frames:v 1 -q:v 2 -pix_fmt yuvj420p -an \
            "$SAVE_BASE/${FILE_NAME_BASE}_$(printf "%03d" $count).jpg" -y >/dev/null 2>&1
        
        # 進捗表示
        percent=$((count * 100 / total_steps))
        echo -ne "進捗: $percent% ($count / $total_steps 枚)\r"
        
        ((count++))
    done
    echo -e "\n完了: $video"
done

if [ "$found" = false ]; then
    zenity --info --text="対象ファイルが見つかりませんでした。"
else
    notify-send "処理完了" "すべての抽出が終了しました。"
fi

echo "===================================================="
echo "完了！ Enterキーで閉じます。"
read
