#!/bin/bash

################################################################################
# Script Name:  video_to_frames_ultimate.sh
# Description:  動画元・保存先・抽出間隔をすべてGUIで設定してキャプチャ抽出
# Version:      1.3.0
################################################################################

echo "===================================================="
echo "   Video Frame Extractor Ver 1.3.0"
echo "===================================================="

# 1. 動画が入っているフォルダを選択
SOURCE_DIR=$(zenity --file-selection --directory --title="1. 動画が入っているフォルダを選択してください")
[ -z "$SOURCE_DIR" ] && exit 0

# 2. 保存先のフォルダを選択
SAVE_BASE=$(zenity --file-selection --directory --title="2. 保存先のフォルダを選択してください" --filename="$HOME/ピクチャ/")
[ -z "$SAVE_BASE" ] && exit 0

# 3. 抽出間隔（秒）をスライダーで選択
# --value: 初期値, --min-value: 最小, --max-value: 最大, --step: 刻み
INTERVAL=$(zenity --scale --title="3. 抽出間隔の設定" \
    --text="何秒ごとに画像を保存しますか？" \
    --value=60 --min-value=1 --max-value=3600 --step=1)
[ -z "$INTERVAL" ] && exit 0

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

    DIR_NAME="${video%.*}"
    TARGET_DIR="$SAVE_BASE/$DIR_NAME"
    mkdir -p "$TARGET_DIR"

    # キャプチャ実行
    # ユーザーが指定した $INTERVAL 秒を反映
    ffmpeg -i "$video" -vf "fps=1/$INTERVAL" -q:v 2 "$TARGET_DIR/${DIR_NAME}_%03d.jpg" -loglevel warning
    echo "完了: $TARGET_DIR"
done

if [ "$found" = false ]; then
    zenity --info --text="対象ファイルが見つかりませんでした。"
else
    # デスクトップ通知を表示（おまけ機能）
    notify-send "処理完了" "すべての動画のキャプチャが完了しました。"
fi

echo "===================================================="
echo "すべての処理が終了しました。"
echo "Enterキーを押すとこのウィンドウを閉じます。"
echo "===================================================="

read
