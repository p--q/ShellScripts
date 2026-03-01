#!/bin/bash
# ==============================================================================
# Script Name: flac-7z-conversion.sh
# Version:     3.2.3 (Real-time File Display)
# ==============================================================================

# 1. 依存チェック
for tool in "zenity" "7z" "flac"; do
    command -v "$tool" &> /dev/null || { zenity --error --text="$tool が見つかりません。"; exit 1; }
done

# 2. フォルダ選択
TARGET_DIRS=$(zenity --file-selection --directory --multiple --separator="|" --title="変換したいNAS上のフォルダを選択してください")
[ $? -ne 0 ] || [ -z "$TARGET_DIRS" ] && exit

# 3. 設定入力
CONFIG=$(zenity --forms --title="音源変換設定 v3.2.3" \
    --text="選択されたフォルダ内の音源を再帰的にFLAC変換し、暗号化保存します。" \
    --add-entry="1. 接尾辞" \
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
        echo "# フォルダをスキャン中: $DIR_NAME"
        echo "5"
        
        # 1/3: コピー進捗（ファイル名を表示）
        echo "# 1/3: NASからコピー中..."
        # cp -v を使い、パイプで一行ずつ読み取ってダイアログに流す
        cp -rv "$TARGET" "$WORK_ROOT/" | while read -r line; do
            # ファイル名だけを抽出して表示
            echo "# コピー中: $(basename "$line")"
        done
        
        COPIED_DIR="${WORK_ROOT}/${DIR_NAME}"

        # 2/3: FLAC変換進捗（ファイル名を表示）
        echo "# 2/3: 再帰的にFLAC変換中..."
        # findの結果をループで回し、一つずつ処理
        while IFS= read -r f; do
            [ -z "$f" ] && continue
            echo "# 変換中: $(basename "$f")"
            flac --silent --force "$f" -o "${f%.*}.flac" && rm "$f"
        done <<< "$(find "$COPIED_DIR" -type f \( -iname "*.wav" -o -iname "*.aiff" \))"

        # 3/3: 暗号化（ここは7zが内部で処理するため、代表メッセージのみ）
        echo "# 3/3: 暗号化保存中: $DIR_NAME"
        echo "80"
        cd "$COPIED_DIR" || exit
        7z a $P_ARG -mhe=off $V_ARG -mx=0 -mmt=on "${WORK_ROOT}/${DIR_NAME}${SUFFIX}.7z" . -y > /dev/null
        
        echo "# 完了ファイルを移動中..."
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
    ) | zenity --progress --title="変換処理進行中" --width=600 --auto-close --pulsate
done

# 5. 最終報告
MSG="すべての変換処理が完了しました。\n\n保存先: ${LOCAL_ARCHIVE_DIR}"
[ -s "$DUP_LOG_FILE" ] && MSG="${MSG}\n\n【連番付与】\n$(cat "$DUP_LOG_FILE" | sort -u)"
rm -f "$DUP_LOG_FILE"
zenity --info --title="変換完了" --text="$MSG"
