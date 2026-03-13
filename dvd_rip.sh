#!/bin/bash

# File: dvd_rip_v3.sh
# Version: 1.3.0
# Description: パスにスペースが含まれるDVD（Christmas Pageant 2025等）に対応

OUTPUT_DIR="$HOME/ビデオ"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="$OUTPUT_DIR/${TIMESTAMP}.mp4"

# --- DVDの自動検出（スペースがあってもOK） ---
DVD_PATH=$(mount | grep -i "udf\|iso9660" | awk -F ' on ' '{print $2}' | awk '{print $1}')
# もし上記でうまく取れない場合は、より確実に /media/pq 配下を探す
if [ -z "$DVD_PATH" ]; then
    DVD_PATH=$(find /media/$USER -maxdepth 1 -mindepth 1 -type d | head -n 1)
fi

# チェック: 変数を必ず "" で囲む
if [ -z "$DVD_PATH" ] || [ ! -d "$DVD_PATH/VIDEO_TS" ]; then
    zenity --error --text="DVDのマウントポイントが見つかりません。\n確認されたパス: $DVD_PATH"
    exit 1
fi

# --- VOBファイルのリストアップ（ここもダブルクォーテーションが重要） ---
VOB_FILES=$(ls "$DVD_PATH/VIDEO_TS"/VTS_01_[1-9].VOB 2>/dev/null | tr '\n' '|' | sed 's/|$//')

if [ -z "$VOB_FILES" ]; then
    zenity --error --text="VOBファイルが見つかりません。VTS_01以外のタイトルの可能性があります。"
    exit 1
fi

# --- 総時間の取得 ---
DURATION=$(ffprobe -i "concat:$VOB_FILES" -show_entries format=duration -v quiet -of csv='p=0')
DURATION_INT=${DURATION%.*}

# --- 変換処理 ---
ffmpeg -i "concat:$VOB_FILES" \
    -c:v libx264 -crf 20 -preset medium -vf "yadif" -c:a aac -b:a 192k \
    -progress pipe:1 -nostats -y "$OUTPUT_FILE" 2>&1 | \
    awk -v dur="$DURATION_INT" '
    /out_time_ms/ {
        split($0, a, "="); 
        sec = a[2] / 1000000;
        pct = (sec / dur) * 100;
        printf "%d\n", pct;
        fflush();
    }' | zenity --progress --title="DVD変換中" --text="保存先: $OUTPUT_FILE" \
               --percentage=0 --auto-close --auto-kill

if [ $? -eq 0 ]; then
    zenity --info --text="完了しました！"
else
    zenity --error --text="変換に失敗しました。"
fi
