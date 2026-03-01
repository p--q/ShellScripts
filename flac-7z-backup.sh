#!/bin/bash
# ==============================================================================
# Script Name: flac-7z-backup.sh
# Version:     2.0.1 (Stable Process - Function Mode)
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
BUFFERED_REQUIRED=$((TOTAL_REQUIRED_KB * 11 / 10))
FREE_SPACE=$(df -Pk "$HOME" | awk 'NR==2 {print $4}')

if [ "$FREE_SPACE" -lt "$BUFFERED_REQUIRED" ]; then
    zenity --error --text="容量不足です。"
    exit 1
fi

# --- 4. 設定入力パネル ---
CONFIG=$(zenity --forms --title="flac-7z-backup v2.0.1" \
    --text="FLAC変換とパスワード保護を自動実行します。" \
    --add-entry="1. ファイル名に付加する接尾辞" \
    --add-entry="2. 分割容量 (例: 4400m) [空欄で分割なし]" \
    --add-password="3. パスワード" \
    --add-password="4. パスワード（確認）" \
    --separator=",")

[ $? -ne 0 ] || [ -z "$CONFIG" ] && exit

SUFFIX=$(echo "$CONFIG" | cut -d',' -f1)
SPLIT_SIZE_RAW=$(echo "$CONFIG" | cut -d',' -f2)
PASS1=$(echo "$CONFIG" | cut -d',' -f3)
PASS2=$(echo "$CONFIG" | cut -d',' -f4)

[ "$PASS1" != "$PASS2" ] && { zenity --error --text="パスワード不一致"; exit 1; }

V_ARG=""; [ -n "$SPLIT_SIZE_RAW" ] && V_ARG="-v${SPLIT_SIZE_RAW}"
P_ARG=""; [ -n "$PASS1" ] && P_ARG="-p${PASS1}"

LOCAL_ARCHIVE_DIR="${HOME}/Backup_Archives"
mkdir -p "$LOCAL_ARCHIVE_DIR"

# 重複ログ用の一時ファイル
DUP_LOG_FILE=$(mktemp)

# --- 5. メイン処理関数 ---
process_backup() {
    local TARGET_DIR="$1"
    local ABS_TARGET_DIR=$(realpath "$TARGET_DIR")
    local DIR_NAME=$(basename "$ABS_TARGET_DIR")
    local OUTPUT_BASE_NAME="${DIR_NAME}${SUFFIX}"
    local LOCAL_WORK_ROOT="${HOME}/.backup_temp_work_$(date +%s)"
    local LOCAL_TEMP_DIR="${LOCAL_WORK_ROOT}/${DIR_NAME}"
    
    echo "# 1/3: ${DIR_NAME} 取り込み & FLAC変換中..."
    mkdir -p "$LOCAL_TEMP_DIR"
    
    cd "$ABS_TARGET_DIR" || return
    find . -type f -print0 | xargs -0 -I{} cp --parents {} "$LOCAL_TEMP_DIR/"
    find "$LOCAL_TEMP_DIR" -type f \( -iname "*.wav" -o -iname "*.aiff" \) -exec sh -c 'flac --silent --force "$1" -o "${1%.*}.flac" && rm "$1"' _ {} \;
    
    echo "50"
    echo "# 2/3: ${DIR_NAME} 暗号化中..."
    cd "$LOCAL_TEMP_DIR" || return
    7z a $P_ARG -mhe=off $V_ARG -mx=0 -mmt=on "${LOCAL_WORK_ROOT}/${OUTPUT_BASE_NAME}.7z" . -y > /dev/null
    
    echo "90"
    echo "# 3/3: ${DIR_NAME} 移動 & 重複チェック中..."
    cd "$LOCAL_WORK_ROOT" || return
    for f in "${OUTPUT_BASE_NAME}.7z"*; do
        [ -e "$f" ] || continue
        local DEST_NAME="$f"
        if [ -e "${LOCAL_ARCHIVE_DIR}/${DEST_NAME}" ]; then
            echo "・ ${DEST_NAME}" >> "$DUP_LOG_FILE"
            local EXT="${f#*.}"
            local BASE="${f%%.7z*}"
            local COUNTER=1
            while [ -e "${LOCAL_ARCHIVE_DIR}/${BASE}(${COUNTER}).${EXT}" ]; do
                ((COUNTER++))
            done
            DEST_NAME="${BASE}(${COUNTER}).${EXT}"
        fi
        mv "$f" "${LOCAL_ARCHIVE_DIR}/${DEST_NAME}"
    done
    rm -rf "$LOCAL_WORK_ROOT"
    echo "100"
}

# --- 6. 実行 ---
IFS="|"
for DIR in $TARGET_DIRS; do
    [ -z "$DIR" ] && continue
    process_backup "$DIR"
done | zenity --progress --title="バックアップ実行中" --auto-close --pulsate

# --- 7. 最終ダイアログ ---
MSG="処理が完了しました。\n\n保存先: ${LOCAL_ARCHIVE_DIR}"
if [ -s "$DUP_LOG_FILE" ]; then
    DUPS=$(cat "$DUP_LOG_FILE" | sort -u)
    MSG="${MSG}\n\n【注意】以下のファイル名は既に存在していたため、連番を付けて保存しました：\n${DUPS}"
fi

rm -f "$DUP_LOG_FILE"
zenity --info --title="完了" --text="$MSG"
