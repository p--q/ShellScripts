#!/bin/bash

################################################################################
# Script Name:  video_to_frames_gui.sh
# Description:  フォルダ内の動画を60秒ごとにキャプチャ。保存先をGUIで選択可能。
# Version:      1.1.0
################################################################################

echo "===================================================="
echo "   Video Frame Extractor Ver 1.1.0"
echo "===================================================="

# 1. GUIで保存先ディレクトリを選択
# --file-selection: ファイル選択ダイアログを表示
# --directory: フォルダ選択モード
# --title: ダイアログのタイトル
SAVE_BASE=$(zenity --file-selection --directory --title="保存先のフォルダを選択してください" --filename="$HOME/ピクチャ/")

# キャンセルされた（保存先が空）場合の処理
if [ -z "$SAVE_BASE" ]; then
    echo "キャンセルされました。終了します。"
    sleep 2
    exit 0
fi

echo "保存先: $SAVE_BASE"

# ffmpegチェック
if ! command -v ffmpeg &> /dev/null; then
    zenity --error --text="ffmpeg がインストールされていません。\nsudo apt install ffmpeg を実行してください。"
    exit 1
fi

# 動画ファイルの処理
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
    ffmpeg -i "$video" -vf "fps=1/60" -q:v 2 "$TARGET_DIR/${DIR_NAME}_%03d.jpg" -loglevel warning
    echo "完了: $TARGET_DIR"
done

if [ "$found" = false ]; then
    echo "このフォルダには対象となる動画ファイルが見つかりませんでした。"
fi

echo "===================================================="
echo "すべての処理が終了しました。"
echo "Enterキーを押すとこのウィンドウを閉じます。"
echo "===================================================="

read
