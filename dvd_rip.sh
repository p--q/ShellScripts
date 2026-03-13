#!/bin/bash

# File: dvd_rip.sh
# Version: 1.1.0
# Description: DVD(VOB)を年月日時分秒.mp4形式で ~/ビデオ に保存します。
#              Debian Cinnamon環境向け（zenityダイアログ、インターレース解除込）

# --- 設定 ---
# 出力先を ~/ビデオ に設定
OUTPUT_DIR="$HOME/ビデオ"
# ファイル名を「年月日時分秒.mp4」に設定
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="$OUTPUT_DIR/${TIMESTAMP}.mp4"

# 出力先ディレクトリが存在しない場合は作成
mkdir -p "$OUTPUT_DIR"

# --- 依存パッケージのチェック ---
MISSING_PKGS=""
for pkg in ffmpeg zenity; do
    if ! command -v $pkg &> /dev/null; then
        MISSING_PKGS="$MISSING_PKGS $pkg"
    fi
done

if [ -n "$MISSING_PKGS" ]; then
    zenity --error --title="システムチェック" \
        --text="実行に必要なツールが不足しています:\n\n$MISSING_PKGS\n\nターミナルで以下を実行してインストールしてください:\nsudo apt update && sudo apt install $MISSING_PKGS"
    exit 1
fi

# --- DVDドライブの自動検出 ---
DVD_PATH=$(mount | grep -i "udf\|iso9660" | awk '{print $3}' | head -n 1)

if [ -z "$DVD_PATH" ] || [ ! -d "$DVD_PATH/VIDEO_TS" ]; then
    zenity --error --title="エラー" --text="DVDが見つかりません。ディスクを挿入・マウントしてください。"
    exit 1
fi

# --- VOBファイルのリストアップ ---
# 通常、本編が含まれる VTS_01_1.VOB 以降を結合対象にします
VOB_FILES=$(ls "$DVD_PATH/VIDEO_TS"/VTS_01_[1-9].VOB 2>/dev/null | tr '\n' '|' | sed 's/|$//')

if [ -z "$VOB_FILES" ]; then
    zenity --error --text="DVD内のビデオデータ(VTS_01)が見つかりません。"
    exit 1
fi

# --- 変換処理の実行 ---
(
echo "# 動画の変換を開始しました...\n# 保存先: $OUTPUT_FILE"
ffmpeg -i "concat:$VOB_FILES" \
    -c:v libx264 -crf 20 -preset medium \
    -vf "yadif" \
    -c:a aac -b:a 192k \
    -y "$OUTPUT_FILE" 2>&1
) | zenity --progress --title="DVD変換中" --text="処理中です。完了までお待ちください..." --pulsate --auto-close

# --- 結果の確認 ---
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    zenity --info --title="完了" --text="正常に保存されました。\n\nファイル名: ${TIMESTAMP}.mp4\n場所: $OUTPUT_DIR"
else
    zenity --error --text="変換中に問題が発生しました。ファイルが作成されていない可能性があります。"
fi
