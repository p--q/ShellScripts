#!/bin/bash
# ==============================================================================
# Script Name: flac-7z-backup.sh
# Version:     2.1.2 (Strict Argument Handling for Nemo)
# ==============================================================================

# --- 1. 依存ツールのチェック ---
for tool in "zenity" "7z" "flac"; do
    if ! command -v "$tool" &> /dev/null; then
        zenity --error --text="必要なツール ($tool) が見つかりません。"
        exit 1
    fi
done

# --- 2. ターゲットの取得 (判定ロジックを刷新) ---
TARGET_DIRS=""

# Nemoの環境変数、または引数 ($@) があるかチェック
if [ -n "$NEMO_SCRIPT_SELECTED_FILE_PATHS" ]; then
    # Nemoスクリプト変数がある場合
    TARGET_DIRS=$(echo "$NEMO_SCRIPT_SELECTED_FILE_PATHS" | tr '\n' '|')
elif [ $# -gt 0 ]; then
    # 引数が1つ以上存在する場合（Nemoの標準的な挙動はこちら）
    for arg in "$@"; do
        # 絶対パスに変換して連結
        ABS_PATH=$(realpath "$arg")
        [ -d "$ABS_PATH" ] && TARGET_DIRS="${TARGET_DIRS}${ABS_PATH}|"
    done
fi

# 末尾のパイプを削除
TARGET_DIRS="${TARGET_DIRS%|}"

# もしここまでで空なら、初めてダイアログを出す
if [ -z "$TARGET_DIRS" ]; then
    TARGET_DIRS=$(zenity --file-selection --directory --multiple --separator="|" --title="NAS上のフォルダを選択してください")
fi

# それでも空（キャンセル）なら終了
[ -z "$TARGET_DIRS" ] && exit

# --- 3. 動的な空き容量チェック ---
TOTAL_REQUIRED_KB=0
OLD_IFS=$IFS
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
CONFIG=$(zenity --forms --title="flac-7z-backup v2.1.2" \
    --text="FLAC変換とパスワード保護を実行します。" \
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
DUP_LOG_FILE=$(mktemp)

# --- 5. メイン処理関数 ---
process_backup() {
    local TARGET_DIR="$1"
    local ABS_TARGET_DIR=$(realpath "$TARGET_DIR")
    local DIR_NAME=$(basename "$ABS_TARGET_DIR")
    local OUTPUT_BASE_NAME="${DIR_NAME}${SUFFIX}"
    local LOCAL_WORK_ROOT="${HOME}/.backup_temp_work_$(date +%s)"
    local LOCAL_TEMP_DIR="${LOCAL_WORK_ROOT}/${DIR_NAME}"
    
    mkdir -p "$LOCAL_TEMP_DIR"
    
    (
        echo "# 1/3: ${DIR_NAME} 取り込み & FLAC変換中..."
        cd "$ABS_TARGET_DIR" || exit
        find . -type f -print0 | xargs -0 -I{} cp --parents {} "$LOCAL_TEMP_DIR/"
        find "$LOCAL_TEMP_DIR" -type f \( -iname "*.wav" -o -iname "*.aiff" \) -exec sh -c 'flac --silent --force "$1" -o "${1%.*}.flac" && rm "$1"' _ {} \;
        
        echo "50"
        echo "# 2/3: ${DIR_NAME} 暗号化中..."
        cd "$LOCAL_TEMP_DIR" || exit
        7z a $P_ARG -mhe=off $V_ARG -mx=0 -mmt=on "${LOCAL_WORK_ROOT}/${OUTPUT_BASE_NAME}.7z" . -y > /dev/null
        
        echo "90"
        echo "# 3/3: ${DIR_NAME} 移動 & 重複チェック中..."
        cd "$LOCAL_WORK_ROOT" || exit
        for f in "${OUTPUT_BASE_NAME}.7z"*; do
            [ -e "$f" ] || continue
            local DEST_NAME="$f"
            if [ -e "${LOCAL_ARCHIVE_DIR}/${DEST_NAME}" ]; then
                echo "・ ${DEST_NAME}" >> "$DUP_LOG_FILE"
                local EXT="${f#*.}"
                local BASE="${f%%.7z*}"
                local COUNTER=1
                while [ -e "${LOCAL_ARCHIVE_DIR}/${BASE}(${COUNTER}).${EXT}" ]; do
