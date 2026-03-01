#!/bin/bash
# ==============================================================================
# Script Name: flac-7z-backup.sh
# Version:     1.9.7 (Final Polish - Info Dialog Restored)
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
CONFIG=$(zenity --forms --title="flac-7z-backup v1.9.7" \
    --text="FLAC変換とパスワード保護を自動実行します。" \
    --add-entry="1. ファイル名に付加する接尾辞" \
    --add-entry="2. 分割容量 (例: 4400m) [空欄で分割なし]" \
    --add-password="3. パスワード" \
    --add-password="4. パスワード（確認）" \
    --separator=",")

[ $? -ne 0 ] || [ -z "$CONFIG" ] && exit

# パース
SUFFIX=$(echo "$CONFIG" | cut -d',' -f1)
SPLIT_SIZE_RAW=$(echo "$CONFIG" | cut -d',' -f2)
PASS1=$(echo "$CONFIG" | cut -d',' -f3)
PASS2=$(echo "$CONFIG" | cut -d',' -f4)

# パスワード一致チェック
if [ "$PASS1" != "$PASS2" ]; then
    zenity --error --text="パスワードが一致しません。\nもう一度やり直してください。"
    exit 1
fi

# 7zオプションの構築
V_ARG=""; [ -n "$SPLIT_SIZE_RAW" ] && V_ARG="-v${SPLIT_SIZE_RAW}"
P_ARG=""; [ -n "$PASS1" ] && P_ARG="-p${PASS1}"

LOCAL_ARCHIVE_DIR="${HOME}/Backup_Archives"
mkdir -p "$LOCAL_ARCHIVE_DIR"

# --- 5. メイン処理 ---
IFS="|"
for TARGET_DIR in $TARGET_DIRS; do
    [ -z "$TARGET_DIR" ] && continue

    ABS_TARGET_DIR=$(realpath "$TARGET_DIR")
    DIR_NAME=$(basename "$ABS_TARGET_DIR")
    OUTPUT_BASE_NAME="${DIR_NAME}${SUFFIX}"

    LOCAL_WORK_ROOT="${HOME}/.backup_temp_work_$(date +%s)"
    LOCAL_TEMP_DIR="${LOCAL_WORK_ROOT}/${DIR_NAME}"
    mkdir -p "$LOCAL_TEMP_DIR"

    (
        echo "# 1/3: 取り込み & 自動FLAC変換中..."
        cd "$ABS_TARGET_DIR" || exit
        find . -type f -print0 | xargs -0 -I{} cp --parents {} "$LOCAL_TEMP_DIR/"
        
        find "$LOCAL_TEMP_DIR" -type f \( -iname "*.wav" -o -iname "*.aiff" \) -exec sh -c 'flac --silent --force "$1" -o "${1%.*}.flac" && rm "$1"' _ {} \;
        echo "50"

        echo "# 2/3: 暗号化中 (高速)..."
        cd "$LOCAL_TEMP_DIR" || exit
        7z a $P_ARG -mhe=off $V_ARG -mx=0 -mmt=on "${LOCAL_WORK_ROOT}/${OUTPUT_BASE_NAME}.7z" . -y > /dev/null
        echo "90"

        echo "# 3/3: 最終保存先へ移動中..."
        cd "$LOCAL_WORK_ROOT" || exit
        for f in "${OUTPUT_BASE_NAME}.7z"*; do
            [ -e "$f" ] || continue
            mv "$f" "${LOCAL_ARCHIVE_DIR}/"
        done
        
        rm -rf "$LOCAL_WORK_ROOT"
        echo "100"
    ) | zenity --progress --title="処理中: $DIR_NAME" --auto-close --pulsate
done

# --- 【修正済み】完了ダイアログ ---
zenity --info --title="完了" --text="処理が完了しました。\n\n保存先: ${LOCAL_ARCHIVE_DIR}"
