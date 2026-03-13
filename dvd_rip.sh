#!/bin/bash

# File: dvd_rip_v2.sh
# Version: 1.2.0
# Description: 進捗状況を%で表示しながらDVDをMP4に変換します。

OUTPUT_DIR="$HOME/ビデオ"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="$OUTPUT_DIR/${TIMESTAMP}.mp4"

# --- DVDの自動検出とパス取得 ---
DVD_PATH=$(mount | grep -i "udf\|iso9660" | awk '{print $3}' | head -n 1)
VOB_FILES=$(ls "$DVD_PATH/VIDEO_TS"/VTS_01_[1-9].VOB 2>/dev/null | tr '\n' '|' | sed 's/|$//')

if [ -z "$VOB_FILES" ]; then
    zenity --error --text="DVDが見つかりません。"
    exit 1
fi

# --- 総再生時間の取得（%計算用） ---
# 最初のVOBファイルから全体の長さを推測
DURATION=$(ffprobe -i "concat:$VOB_FILES" -show_entries format=duration -v quiet -of csv='p=0')
DURATION_INT=${DURATION%.*}

# --- 変換処理（進捗計算付き） ---
# FFmpegの経過時間を秒に変換し、総時間で割って100を掛ける
ffmpeg -i "concat:$VOB_FILES" \
    -c:v libx264 -crf 20 -preset medium -vf "yadif" -c:a aac -b:a 192k \
    -progress pipe:1 -nostats -y "$OUTPUT_FILE" 2>&1 | \
    awk -v dur="$DURATION_INT" '
    /out_time_ms/ {
        # ミクロ秒を秒に変換
        split($0, a, "="); 
        ms = a[2]; 
        sec = ms / 1000000;
        # 進捗率を計算して出力
        pct = (sec / dur) * 100;
        printf "%d\n", pct;
        fflush();
    }' | zenity --progress --title="DVD変換中" --text="動画を解析・変換しています..." \
               --percentage=0 --auto-close --auto-kill

if [ $? -eq 0 ]; then
    zenity --info --title="完了" --text="保存完了: $OUTPUT_FILE"
else
    zenity --error --text="処理がキャンセルされたか、エラーが発生しました。"
fi
