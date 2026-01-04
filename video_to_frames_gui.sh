#!/bin/bash

################################################################################
# Script Name:  video_to_frames_timestamp.sh
# Description:  動画から指定秒ごとに、再生時間をファイル名に含めて直接保存
# Version:      1.5.0
################################################################################

echo "===================================================="
echo "   Video Frame Extractor Ver 1.5.0"
echo "===================================================="

# 1. フォルダと間隔の選択
SOURCE_DIR=$(zenity --file-selection --directory --title="1. 動画が入っているフォルダを選択してください")
[ -z "$SOURCE_DIR" ] && exit 0

SAVE_BASE=$(zenity --file-selection --directory --title="2. 保存先のフォルダを選択してください" --filename="$HOME/ピクチャ/")
[ -z "$SAVE_BASE" ] && exit 0

INTERVAL=$(zenity --scale --title="3. 抽出間隔の設定" \
    --text="何秒ごとに画像を保存しますか？" \
    --value=60 --min-value=1 --max-value=3600 --step=1)
[ -z "$INTERVAL" ] && exit 0

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

    # ファイル名に時刻を含めるためのffmpeg処理
    # -vf fps=1/$INTERVAL: 指定間隔で抽出
    # filename に %04d の代わりにタイムスタンプを模した連番を付与
    # ※ffmpeg標準機能で「ファイル名に秒数」を入れるため、
    # 後のリネーム処理が不要なスクリプト構成にしています。
    
    ffmpeg -i "$video" -vf "fps=1/$INTERVAL" -q:v 2 \
        -f image2 -frame_pts 1 \
        "$SAVE_BASE/${FILE_NAME_BASE}_pts%d.jpg" -loglevel warning

    # 生成されたファイル名 (pts120.jpg等) を「00h02m00s」形式にリネーム
    # この工程で「動画内の秒数」を読みやすい形式に変換します
    for img in "$SAVE_BASE/${FILE_NAME_BASE}_pts"*.jpg; do
        [ -e "$img" ] || continue
        
        # ptsの後の数字（秒数相当）を抽出
        pts_val=$(echo "$img" | grep -oP 'pts\K[0-9]+')
        
        # 秒を 時:分:秒 に変換
        h=$((pts_val / 3600))
        m=$(((pts_val % 3600) / 60))
        s=$((pts_val % 60))
        
        timestamp=$(printf "%02dh%02dm%02ds" $h $m $s)
        
        # 最終的なリネーム
        mv "$img" "$SAVE_BASE/${FILE_NAME_BASE}_${timestamp}.jpg"
    done

    echo "完了: $video"
done

if [ "$found" = false ]; then
    zenity --info --text="対象ファイルが見つかりませんでした。"
else
    notify-send "処理完了" "時刻付きファイル名の保存が完了しました。"
fi

echo "===================================================="
echo "完了！ Enterで閉じます。"
read
