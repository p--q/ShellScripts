#!/bin/bash

# File: dvd_rip_v3_1.sh
# Description: スペースを含むマウントポイント（Christmas Pageant2025等）に完全対応

OUTPUT_DIR="$HOME/ビデオ"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="$OUTPUT_DIR/${TIMESTAMP}.mp4"

# --- DVDの自動検出（もっとも確実な方法に変更） ---
# dfコマンドから、DVD（/dev/sr0）がマウントされている場所を直接抽出します
DVD_PATH=$(df --output=target /dev/sr0 2>/dev/null | tail -n 1)

# チェック: パスが空、またはディレクトリが存在しない場合
if [ -z "$DVD_PATH" ] || [ "$DVD_PATH" = "target" ]; then
    zenity --error --text="DVDドライブ(sr0)がマウントされていません。\nディスクを入れて数秒待ってから再試行してください。"
    exit 1
fi

# 確認用メッセージ（デバッグ用：不要なら消してOK）
echo "Detected DVD Path: [$DVD_PATH]"

# --- VOBファイルのリストアップ（変数を必ず "" で囲む） ---
# findコマンドを使ってスペース入りのパスでも確実にファイルを繋げます
VOB_FILES=$(find "$DVD_PATH/VIDEO_TS" -name "VTS_01_[1-9].VOB" | sort | tr '\n' '|' | sed 's/|$//')

if [ -z "$VOB_FILES" ]; then
    zenity --error --text="VOBファイルが見つかりません。\nパス: $DVD_PATH/VIDEO_TS"
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
        if (dur > 0) {
            pct = (sec / dur) * 100;
            printf "%d\n", pct;
        }
        fflush();
    }' | zenity --progress --title="DVD変換中" --text="保存先: $OUTPUT_FILE\n進捗を確認しています..." \
               --percentage=0 --auto-close --auto-kill

if [ $? -eq 0 ]; then
    zenity --info --text="完了しました！\nファイル: $OUTPUT_FILE"
else
    zenity --error --text="変換に失敗したか、キャンセルされました。"
fi
