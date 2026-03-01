#!/bin/bash
# ==============================================================================
# Script Name: flac-7z-backup.sh
# Version:     1.9.2 (Fixed Parsing)
# ==============================================================================

# --- 1. 依存ツールのチェック ---
for tool in "zenity" "7z" "flac"; do
    if ! command -v "$tool" &> /dev/null; then
        zenity --error --text="必要なツール ($tool) が見つかりません。"
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
    zenity --error --text="容量不足です。"
    exit 1
fi

# --- 4. 設定入力パネル ---
CONFIG=$(zenity --forms --title="flac-7z-backup v1.9.2" \
    --text="FLAC変換後、無圧縮7zで暗号化します。" \
    --add-combo="1. オーディオをFLACに変換するか" --combo-values="yes|no" \
    --add-entry="2. 分割容量 (例: 4400m)" \
    --add-entry="3. ファイル名に付加する接尾辞" \
    --add-password="4. パスワード" \
    --add-password="5. パスワード（確認）" \
    --separator=",")

[ $? -ne 0 ] || [ -z "$CONFIG" ] && exit

# --- 【修正ポイント】パース処理の正確な割り当て ---
DO_FLAC_RAW=$(echo "$CONFIG" | cut -d',' -f1)
SPLIT_SIZE_RAW=$(echo "$CONFIG" | cut -d',' -f2); SPLIT_SIZE=${SPLIT_SIZE_RAW:-4400m}
SUFFIX=$(echo "$CONFIG" | cut -d',' -f3)
PASS1=$(echo "$CONFIG" | cut -d',' -f4)
PASS2=$(echo "$CONFIG" | cut -d',' -f5)

[ "$DO_FLAC_RAW" != "no" ] && DO_FLAC="yes" || DO_FLAC="no"
[ "$PASS1" != "$PASS2" ] && { zenity --error --text="パスワード不一致"; exit 1; }
P_ARG=""; [ -n "$PASS1" ] && P_ARG="-p${PASS1}"

LOCAL_ARCHIVE_DIR="${HOME}/Backup_Archives"
mkdir -p "$LOCAL_ARCHIVE_DIR"

# --- 5. メイン処理 ---
IFS="|"
for TARGET_DIR in $TARGET_DIRS; do
    [ -z "$TARGET_DIR" ] && continue

    ABS_TARGET_DIR=$(realpath "$TARGET_DIR")
    DIR_NAME=$(basename "$ABS_TARGET_DIR")
    OUTPUT_BASE_NAME="${DIR_NAME}${SUFFIX}.7z"

    LOCAL_WORK_ROOT="${HOME}/.backup_temp_work_$(date +%s)"
    LOCAL_TEMP_DIR="${LOCAL_WORK_ROOT}/${DIR_NAME}"
    mkdir -p "$LOCAL_TEMP_DIR"

    # デバッグ用に出力をターミナルにも出す設定
    (
        echo "# NASから取り込み開始: $DIR_NAME"
        mapfile -t ALL_FILES < <(cd "$ABS_TARGET_DIR" && find . -type f)
