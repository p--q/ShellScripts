#!/bin/bash
# ==============================================================================
# Script Name: flac-7z-backup.sh
# Version:     1.9.3 (Debug & 7z Fix)
# ==============================================================================

# --- 1. 依存ツールのチェック ---
for tool in "zenity" "7z" "flac"; do
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
    zenity --error --text="容量不足です。"
    exit 1
fi

# --- 4. 設定入力パネル ---
CONFIG=$(zenity --forms --title="flac-7z-backup v1.9.3" \
    --text="FLAC変換後、無圧縮7zで暗号化します。" \
    --add-combo="1. オーディオをFLACに変換するか" --combo-values="yes|no" \
    --add-entry="2. 分割容量 (例: 4400m)" \
    --add-entry="3. ファイル名に付加する接尾辞" \
    --add-password="4. パスワード" \
    --add-password="5. パスワード（確認）" \
    --separator=",")

[ $? -ne 0 ] || [ -z "$CONFIG" ] && exit

# --- パース処理の修正 ---
DO_FLAC_RAW=$(echo "$CONFIG" | cut -d',' -f1)
SPLIT_SIZE_RAW=$(echo "$CONFIG" | cut -d',' -f2); SPLIT_SIZE=${SPLIT_SIZE_RAW:-4400m}
SUFFIX=$(echo "$CONFIG" | cut -d',' -f3)
PASS1=$(echo "$CONFIG" | cut -d',' -f4)
PASS2=$(echo "$CONFIG" | cut -d',' -f5)

[ "$DO_FLAC_RAW" != "no" ] && DO_FLAC="yes" || DO_FLAC="no"
[ "$PASS1" != "$PASS2" ] && { zenity --error --text="パスワード不一致"; exit 1; }

# パスワード引数の構築（空でない場合のみ）
P_ARG=""
if [ -n "$PASS1" ]; then
    P_ARG="-p${PASS1}"
fi

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

    (
        echo "# 1/4: NASから取り込み中..."
        cd "$ABS_TARGET_DIR" || exit
        find . -type f -print0 | xargs -0 -I{} cp --parents {} "$LOCAL_TEMP_DIR/"
        echo "25"

        if [ "$DO_FLAC" = "yes" ]; then
            echo "# 2/4: FLAC変換中..."
            find "$LOCAL_TEMP_DIR" -type f \( -iname "*.wav" -o -iname "*.aiff" \) -exec sh -c 'flac --silent --force "$1" -o "${1%.*}.flac" && rm "$1"' _ {} \;
        fi
        echo "50"

        echo "# 3/4: 7z暗号化中 (時間がかかる場合があります)..."
        cd "$LOCAL_TEMP_DIR" || exit
        # 無圧縮モード(-mx=0)で暗号化。パスワードが空でも動作するように修正
        if [ -n "$P_ARG" ]; then
            7z a $P_ARG -mhe=off -v"${SPLIT_SIZE}" -mx=0 -mmt=on "${LOCAL_WORK_ROOT}/out.7z" . -y > /dev/null
        else
            7z a -v"${SPLIT_SIZE}" -mx=0 -mmt=on "${LOCAL_WORK_ROOT}/out.7z" . -y > /dev/null
        fi
        echo "75"

        echo "# 4/4: 保存先へ移動中..."
        cd "$LOCAL_WORK_ROOT" || exit
        for f in out.7z*; do
            [ -e "$f" ] || continue
            DEST_NAME=$(echo "$f" | sed "s/out.7z/${OUTPUT_BASE_NAME}/")
            cp "$f" "${LOCAL_ARCHIVE_DIR}/${DEST_NAME}"
        done
        
        rm -rf "$LOCAL_WORK_ROOT"
        echo "100"
    ) | zenity --progress --title="処理中: $DIR_NAME" --auto-close --pulsate
done

zenity --info --title="完了" --text="処理が完了しました。\n保存先: ${LOCAL_ARCHIVE_DIR}"
