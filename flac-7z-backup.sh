#!/bin/bash
# ==============================================================================
# Script Name: flac-7z-backup.sh
# Version:     1.6
# Description: NAS上のフォルダを対象とした、大容量対応バックアップスクリプト。
#              ローカルの高速な作業領域を利用して以下の処理を自動化します：
#              1. 作業領域の空き容量確認（40GB以上）
#              2. 指定したNASフォルダからのデータ取り込み
#              3. 音声ファイル（WAV/AIFF）のFLAC変換（オプション）
#              4. 7z形式での分割圧縮およびAES-256暗号化
#              5. 成果物のNASへの書き戻し ＆ ローカル保存（~/Backup_Archives）
# Requirements: zenity, p7zip-full, flac
# ==============================================================================

# --- 1. 依存ツールのチェック ---
MISSING_TOOLS=("zenity" "7z" "flac")
for tool in "${MISSING_TOOLS[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        zenity --error --text="必要なツール ($tool) が見つかりません。インストールしてください。"
        exit 1
    fi
done

# --- 2. 空き容量の事前チェック (40GB以上必要) ---
FREE_SPACE=$(df -Pk "$HOME" | awk 'NR==2 {print $4}')
REQUIRED_SPACE=41943040
if [ "$FREE_SPACE" -lt "$REQUIRED_SPACE" ]; then
    zenity --error --text="内蔵ストレージの空き容量が不足しています。\n最低40GB必要ですが、現在の空きは $((FREE_SPACE / 1024 / 1024))GB です。"
    exit 1
fi

# --- 3. フォルダ選択 ---
TARGET_DIRS=$(zenity --file-selection --directory --multiple --separator="|" --title="NAS上のフォルダを選択してください")
[ $? -ne 0 ] || [ -z "$TARGET_DIRS" ] && exit

# --- 4. 設定入力パネル ---
CONFIG=$(zenity --forms --title="flac-7z-backup v1.6" \
    --text="PCの内蔵ストレージを作業領域に使用し、完了後はローカルにも保存します。" \
    --add-combo="1. オーディオをFLACに変換するか [既定: yes]" --combo-values="yes|no" \
    --add-entry="2. 7z圧縮レベル (0-9) [既定: 3]" \
    --add-entry="3. 分割容量 (例: 4400m) [既定: 4400m]" \
    --add-entry="4. ファイル名に付加する文字列[既定: '']" \
    --add-password="5. パスワード[既定: '']" \
    --add-password="6. パスワード（確認）" \
    --separator=",")

[ $? -ne 0 ] || [ -z "$CONFIG" ] && exit

# パース
DO_FLAC_RAW=$(echo "$CONFIG" | cut -d',' -f1)
COMP_LEVEL_INPUT=$(echo "$CONFIG" | cut -d',' -f2)
SPLIT_SIZE_RAW=$(echo "$CONFIG" | cut -d',' -f3); SPLIT_SIZE=${SPLIT_SIZE_RAW:-4400m}
SUFFIX=$(echo "$CONFIG" | cut -d',' -f4)
PASS1=$(echo "$CONFIG" | cut -d',' -f5)
PASS2=$(echo "$CONFIG" | cut -d',' -f6)

[ "$DO_FLAC_RAW" != "no" ] && DO_FLAC="yes" || DO_FLAC_NO="no"
[ "$DO_FLAC" = "yes" ] && COMP_LEVEL=0 || COMP_LEVEL=${COMP_LEVEL_INPUT:-3}
[ "$PASS1" != "$PASS2" ] && { zenity --error --text="パスワード不一致"; exit 1; }
P_ARG=""; [ -n "$PASS1" ] && P_ARG="-p${PASS1}"

# ローカル保存用フォルダ作成
LOCAL_ARCHIVE_DIR="${HOME}/Backup_Archives"
mkdir -p "$LOCAL_ARCHIVE_DIR"

# --- 5. メイン処理 ---
IFS="|"
for TARGET_DIR in $TARGET_DIRS; do
    [ -z "$TARGET_DIR" ] && continue

    ABS_TARGET_DIR=$(realpath "$TARGET_DIR")
    DIR_NAME=$(basename "$ABS_TARGET_
