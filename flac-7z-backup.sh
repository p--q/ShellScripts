#!/bin/bash
# ==============================================================================
# Script Name: flac-7z-conversion.sh
# Version:     3.2.2 (Conversion Title & Start Notification)
# ==============================================================================

# 1. 依存チェック
for tool in "zenity" "7z" "flac"; do
    command -v "$tool" &> /dev/null || { zenity --error --text="$tool が見つかりません。"; exit 1; }
done

# 2. フォルダ選択 (タイトルを「変換」に変更)
TARGET_DIRS=$(zenity --file-selection --directory --multiple --separator="|" --title="変換したいNAS上のフォルダを選択してください")
[ $? -ne 0 ] || [ -z "$TARGET_DIRS" ] && exit

# 3. 設定入力 (タイトルを「変換」に変更)
CONFIG=$(zenity --forms --title="音源変換設定 v3.2.2" \
    --text="選択されたフォルダ内の音源を再帰的にFLAC変換し、暗号化保存します。" \
    --add-entry="1. 接尾辞 (ファイル名の末尾に追加)" \
    --add-entry="2. 分割容量 (例: 4400m)" \
    --add-password="3. パスワード" \
    --add-password="4. 確認" \
    --separator=",")

[ $? -ne 0 ] || [ -z "$CONFIG" ] && exit

SUFFIX=$(echo "$CONFIG" | cut -d',' -f1)
SPLIT_SIZE=$(echo "$CONFIG" | cut -d',' -f2)
PASS1=$(echo "$CONFIG" | cut -d',' -f3)
PASS2=$(echo "$CONFIG" | cut -d',' -f4)

[ "$PASS1" != "$PASS2" ] && { zenity --error --text="パスワードが一致しません"; exit 1; }

V_ARG=""; [ -n "$SPLIT_SIZE" ] && V_ARG="-v${SPLIT_SIZE}"
P_ARG=""; [ -n "$PASS1" ] && P_ARG="-p${PASS1}"

LOCAL_ARCHIVE_DIR="${HOME}/Converted_Archives"
mkdir -p "$LOCAL_ARCHIVE_DIR"
DUP_LOG_FILE=$(mktemp)

# 4. 処理ループ
IFS="|"
for TARGET in $TARGET_DIRS; do
    [ -z "$TARGET" ] && continue
    DIR_NAME=$(basename "$TARGET")
    WORK_ROOT="${HOME}/.conv_temp_$(date +%s)"
    mkdir -p "$WORK_ROOT"

    (
        # 即座にどのフォルダを処理するか表示
        echo "# フォルダを認識しました: $DIR_NAME"
        echo "10"
        sleep 1
        
        echo "# 1/3: NASからデータを読み込み中... ($DIR_NAME)"
        # cp -av を使用。NASからの応答待ちの間もタイトルが表示され続ける
        cp -r "$TARGET" "$WORK_ROOT/" > /dev/null 2>&1
        
        COPIED_DIR="${WORK_ROOT}/${DIR_NAME}"

        echo "# 2/3: 再帰的にFLAC変換中... ($DIR_NAME)"
        find "$COPIED_DIR" -type f \( -iname "*.wav" -o -iname "*.aiff" \) -exec sh -c '
            for f do
                echo "# 変換中: $(basename "$f")"
                flac --silent --force "$f" -o "${file%.*}.flac" && rm "$f"
            done
        ' _ {} +
        echo "70"

        echo "# 3/3: 7z暗号化中... ($DIR_NAME)"
        cd "$COPIED_DIR" || exit
        7z a $P_ARG -mhe=off $V_ARG -mx=0 -mmt=on "${WORK_ROOT}/${DIR_NAME}${SUFFIX}.7z" . -y > /dev/null
        
        echo "# 処理完了ファイルを保存先へ移動中..."
        cd "$WORK_ROOT" || exit
        for f in "${DIR_NAME}${SUFFIX}.7z"*; do
            [ -e "$f" ] || continue
            DEST_NAME="$f"
            if [ -e "${LOCAL_ARCHIVE_DIR}/${DEST_NAME}" ]; then
                echo "$f" >> "$DUP_LOG_FILE"
                EXT="${f#*.}"
                BASE="${f%%.7z*}"
                COUNTER=1
                while [ -e "${LOCAL_ARCHIVE_DIR}/${BASE}(${COUNTER}).${EXT}" ]; do
                    ((COUNTER++))
                done
                DEST_NAME="${BASE}(${COUNTER}).${EXT}"
            fi
            mv "$f" "${LOCAL_ARCHIVE_DIR}/${DEST_NAME}"
        done
        
        rm -rf "$WORK_ROOT"
        echo "100"
    ) | zenity --progress --title="変換処理進行中" --width=500 --auto-close --pulsate
done

# 5. 最終報告
MSG="すべての変換処理が完了しました。\n\n保存先: ${LOCAL_ARCHIVE_DIR}"
if [ -s "$DUP_LOG_FILE" ]; then
    DUPS=$(cat "$DUP_LOG_FILE" | sort -u)
    MSG="${MSG}\n\n【注意】同名ファイルが存在したため連番を付与しました：\n${DUPS}"
fi

rm -f "$DUP_LOG_FILE"
zenity --info --title="変換完了" --text="$MSG"
