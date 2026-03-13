#!/bin/bash

# File: dvd_rip.sh
# Version: 1.3.1
# Description: 進捗(%)表示付きDVD取り込みスクリプト。
#              スペースを含むマウントポイントやVOB連結処理に対応。

OUTPUT_DIR="$HOME/ビデオ"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="$OUTPUT_DIR/${TIMESTAMP}.mp4"

# --- DVDの自動検出（ドライブデバイスから直接パスを取得） ---
DVD_PATH=$(df --output=target /dev/sr0 2>/dev/null | tail -n 1)

# チェック: マウントされていない場合
if [ -z "$DVD_PATH" ] || [ "$DVD_PATH" = "target" ]; then
    zenity --error --text="DVDドライブが認識されていません。\nディスクを入れて数秒待ってから実行してください。"
    exit 1
fi

# --- VOBファイルのリストアップ（スペース対応） ---
VOB_FILES=$(find "$DVD_PATH/VIDEO_TS" -name "VTS_01_[1-9].VOB" | sort | tr '\n' '|' | sed 's/|$//')

if [ -z "$VOB_FILES" ]; then
    zenity --error --text="変換対象のVOBファイルが見つかりません。\nパス: $DVD_PATH/VIDEO_TS"
    exit 1
fi

# --- 総再生時間の取得（進捗計算用） ---
DURATION=$(ffprobe -i "concat:$VOB_FILES" -show_entries format=duration -v quiet -of csv='p=0')
DURATION_INT=${DURATION%.*}

# --- 変換処理（プログレスバー表示） ---
ffmpeg -i "concat:$VOB_FILES" \
    -c:v libx264 -crf 20 -preset medium -vf "yadif" -c:a aac -b:a 192k \
    -progress pipe:1 -nostats -y "$OUTPUT_FILE" 2>&1 | \
    awk -v dur="$DURATION_INT" '
    /out_time_ms/ {
        split($0, a, "="); 
        sec = a[2] / 1000000;
        if (dur > 0) {
            pct = (sec / dur) * 100;
            printf "%d\n", pct;
        }
        fflush();
    }' | zenity --progress --title="DVD変換実行中" \
               --text="保存先: $OUTPUT_FILE\n変換が完了するまでお待ちください..." \
               --percentage=0 --auto-close --auto-kill

# --- 最終結果の通知 ---
if [ ${PIPESTATUS[1]} -eq 0 ]; then
    zenity --info --title="完了" --text="ビデオの保存が完了しました！\n場所: $OUTPUT_FILE"
else
    zenity --warning --title="中断" --text="処理がキャンセルされたか、エラーが発生しました。"
fi
