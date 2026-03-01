#!/bin/bash
# ==============================================================================
# Script Name: flac-7z-backup.sh
# Version:     1.9.1
# Description: NAS上のフォルダをローカルにコピーし、FLAC変換後に7zで暗号化。
#              ※7zは「無圧縮(ストア)」モードで高速動作します。
#              ※ヘッダー暗号化をオフにし、パスワードなしでファイル名を表示可能にします。
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

# --- 2. フォルダ選択 ---
TARGET_DIRS=$(zenity --file-selection --directory --multiple --separator="|" --title="NAS上のフォルダを選択してください")
[ $? -ne 0 ] || [ -z "$TARGET_DIRS" ] && exit

# --- 3. 動的な空き容量チェック ---
TOTAL_REQUIRED_KB=0
IFS="|"
for DIR in $TARGET_DIRS; do
    [ -z "$DIR" ] && continue
    DIR_SIZE=$(du -sk "$DIR" | cut -f1)
    TOTAL_REQUIRED_KB=$((TOTAL_REQUIRED_KB + DIR_SIZE))
done

BUFFERED_REQUIRED=$((TOTAL_REQUIRED_KB * 12 / 10))
FREE_SPACE=$(df -Pk "$HOME" | awk 'NR==2 {print $4}')

if [ "$FREE_SPACE" -lt "$BUFFERED_REQUIRED" ]; then
    REQUIRED_GB=$(echo "scale=2; $BUFFERED_REQUIRED/1024/1024" | bc)
    FREE_GB=$(echo "scale=2; $FREE_SPACE/1024/1024" | bc)
    zenity --error --text="容量不足です。\n要求: ${REQUIRED_GB} GB / 空き: ${FREE_GB} GB"
    exit 1
fi

# --- 4. 設定入力パネル ---
CONFIG=$(zenity --forms --title="flac-7z-backup v1.9.1" \
    --text="FLAC変換後、無圧縮7zで暗号化します（ファイル名は可視設定）。" \
    --add-combo="1. オーディオをFLACに変換するか [既定: yes]" --combo-values="yes|no" \
    --add-entry="2. 分割容量 (例: 4400m) [既定: 4400m]" \
    --add-entry="3. ファイル名に付加する接尾辞[既定: '']" \
    --add-password="4. パスワード" \
    --add-password="5. パスワード（確認）" \
    --separator=",")

[ $? -ne 0 ] || [ -z "$CONFIG" ] && exit

# パース
DO_FLAC_RAW=$(echo "$CONFIG" | cut -d',' -f1)
SPLIT_SIZE_RAW=$(echo "$CONFIG" | cut -d',' -f3); SPLIT_SIZE=${SPLIT_SIZE_RAW:-4400m} # index修正
SUFFIX=$(echo "$CONFIG" | cut -d',' -f3)
PASS1=$(echo "$CONFIG" | cut -d',' -f4)
PASS2=$(echo "$CONFIG" | cut -d',' -f
