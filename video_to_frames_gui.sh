#!/bin/bash

################################################################################
# Script Name:  video_to_frames_smart_select.sh
# Description:  抽出間隔をボタン（リスト）で選択し、時刻付きファイル名で保存
# Version:      1.6.0
################################################################################

echo "===================================================="
echo "   Video Frame Extractor Ver 1.6.0"
echo "===================================================="

# 1. 動画が入っているフォルダを選択
SOURCE_DIR=$(zenity --file-selection --directory --title="1. 動画が入っているフォルダを選択してください")
[ -z "$SOURCE_DIR" ] && exit 0

# 2. 保存先のフォルダを選択
SAVE_BASE=$(zenity --file-selection --directory --title="2. 保存先のフォルダを選択してください" --filename="$HOME/ピクチャ/")
[ -z "$SAVE_BASE" ] && exit 0

# 3. 抽出間隔を選択（リスト形式）
INTERVAL_CHOICE=$(zenity --list --radiolist --title="3. 抽出間隔の設定" \
    --text="抽出する間隔を選択してください" \
    --column="選択" --column="間隔（秒）" \
    FALSE "10" \
    FALSE "30" \
    TRUE "60" \
    FALSE "120" \
    FALSE "手入力（カスタム）")

[ -z "$INTERVAL_CHOICE" ] && exit 0

# 「手入力」が選ばれた場合は、スライダー（または入力ダイアログ）を出す
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

    # ffmpeg実行
    # -frame_pts 1 を使用して秒数を取得
    ffmpeg -i "$video" -vf "fps=1/$INTERVAL" -q:v 2 \
        -f image2 -frame_pts 1 \
        "$SAVE_BASE/${FILE_NAME_BASE}_pts%d.jpg" -loglevel warning

    # 生成されたファイルを [時h分m秒s] 形式に一括リネーム
    for img in "$SAVE_BASE/${FILE_NAME_BASE}_pts"*.jpg; do
        [ -e "$img" ] || continue
        
        pts_val=$(echo "$img" | grep -oP 'pts\K[0-9]+')
        
        h=$((pts_val / 3600))
        m=$(((pts_val % 3600) / 60))
        s=$((pts_val % 60))
        
        timestamp=$(printf "%02dh%02dm%02ds" $h $m $s)
        
        mv "$img" "$SAVE_BASE/${FILE_NAME_BASE}_${timestamp}.jpg"
    done

    echo "完了: $video"
done

if [ "$found" = false ]; then
    zenity --info --text="対象ファイルが見つかりませんでした。"
else
    notify-send "処理完了" "時刻付き画像（${INTERVAL}秒間隔）の保存が完了しました。"
fi

echo "===================================================="
echo "完了！ Enterで閉じます。"
read
