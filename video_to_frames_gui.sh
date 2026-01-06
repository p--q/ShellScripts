#!/bin/bash

################################################################################
# Script Name:  video_to_frames_recovery.sh
# Description:  画像出力を最優先し、エラーがあっても無視して完走する
# Version:      2.2.2
################################################################################

echo "===================================================="
echo "   Video Frame Extractor Ver 2.2.2 (Recovery)"
echo "===================================================="

# 1. フォルダ選択 (キャンセル時は即終了)
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

# 3. 必須ツールの存在確認
if ! command -v ffmpeg &> /dev/null; then
    echo "エラー: ffmpeg が見つかりません。"
    exit 1
fi

# 4. 動画処理
shopt -s nocaseglob
found=false

# 読み込み元フォルダへ移動
cd "$SOURCE_DIR" || exit

for video in *.{mp4,ts,mkv,avi,wmv}; do
    [ -e "$video" ] || continue
    found=true

    echo "----------------------------------------------------"
    echo "処理開始: $video"

    FILE_NAME_BASE="${video%.*}"
    
    # 再生時間を取得
    duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$video")
    duration_int=${duration%.*}

    count=1
    for (( s=0; s<duration_int; s+=INTERVAL )); do
        # 最もシンプルなffmpegコマンド構成
        # -y は上書き許可
        # 2>/dev/null は警告のみを捨てる（念のため）
        ffmpeg -loglevel quiet -ss "$s" -i "$video" \
            -frames:v 1 -q:v 2 -pix_fmt yuvj420p -an \
            "$SAVE_BASE/${FILE_NAME_BASE}_$(printf "%03d" $count).jpg" -y 2>/dev/null
        
        echo -ne "処理中... $count 枚目完了\r"
        ((count++))
    done
    echo -e "\n完了: $video"
done

# 5. 最終結果表示
echo "===================================================="
if [ "$found" = false ]; then
    echo "動画ファイルが見つかりませんでした。"
else
    echo "すべての画像出力が完了しました。"
    echo ""
    echo "保存先フォルダ:"
    echo "$SAVE_BASE"
fi
echo "===================================================="

# notify-send があれば実行するが、失敗しても無視する設定
notify-send "処理完了" "保存先: $SAVE_BASE" 2>/dev/null || true

echo "Enterキーを押すと閉じます。"
read
