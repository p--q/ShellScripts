#!/bin/bash
# ==============================================================================
# Script Name: flac-7z-backup.sh
# Version:     2.1.6 (Strict Path Capture & Debug Mode)
# ==============================================================================

# --- 1. 依存ツールのチェック ---
for tool in "zenity" "7z" "flac"; do
    if ! command -v "$tool" &> /dev/null; then
        zenity --error --text="必要なツール ($tool) が見つかりません。"
        exit 1
    fi
done

# --- 2. ターゲットの取得 (最優先ロジック) ---
# Nemoが渡す引数をすべて1つの変数にまとめます
RAW_INPUTS="$@"
[ -n "$NEMO_SCRIPT_SELECTED_FILE_PATHS" ] && RAW_INPUTS="$NEMO_SCRIPT_SELECTED_FILE_PATHS"

# 改行やスペースを安全に処理するために一時配列を使用
TARGET_LIST=()
while IFS= read -r line; do
    [ -z "$line" ] && continue
    # パスが smb:// 等で始まっている場合は、Nemo特有の仕様に合わせて調整
    CLEAN_PATH=$(echo "$line" | sed 's|^file://||')
    # もし実在するなら配列に追加
    if [ -e "$CLEAN_PATH" ]; then
        TARGET_LIST+=("$CLEAN_PATH")
    fi
done <<< "$(echo -e "$RAW_INPUTS" | tr '|' '\n')"

# 最終確認
if [ ${#TARGET_LIST[@]} -eq 0 ]; then
    zenity --error --text="NAS上のフォルダを認識できませんでした。\n\n【デバッグ情報】\n引数: $*\n環境変数: $NEMO_SCRIPT_SELECTED_FILE_PATHS"
    exit 1
fi

# --- 3. 動的な空き容量チェック ---
# 配列から合計サイズを計算
TOTAL_REQUIRED_KB=0
for DIR in "${TARGET_LIST[@]}"; do
    SIZE=$(du -sk "$DIR" | awk '{print $1}')
    TOTAL_REQUIRED_KB=$((TOTAL_REQUIRED_KB + SIZE))
done

BUFFERED_REQUIRED=$((TOTAL_REQUIRED_KB * 11 / 10))
FREE_SPACE=$(df -Pk "$HOME" | awk 'NR==2 {print $4}')

if [ "$FREE_SPACE" -lt "$BUFFERED_REQUIRED" ]; then
    zenity --error --text="ローカル側の容量不足です。"
    exit 1
fi

# --- 4. 設定入力パネル ---
CONFIG=$(zenity --forms --title="flac-7z-backup v2.1.6" \
    --text="NAS上の音源を処理します。" \
    --add-entry="1. 接尾辞" \
    --add-entry="2. 分割容量 (例: 4400m)" \
    --add-password="3. パスワード" \
    --add-password="4. 確認" \
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
    local DIR_NAME=$(basename "$TARGET_DIR")
    local OUTPUT_BASE_NAME="${DIR_NAME}${SUFFIX}"
    local LOCAL_WORK_ROOT="${HOME}/.backup_temp_work_$(date +%s)"
    local LOCAL_TEMP_DIR="${LOCAL_WORK_ROOT}/${DIR_NAME}"
    
    mkdir -p "$LOCAL_TEMP_DIR"
    
    (
        echo "# 1/3: NASからコピー中: ${DIR_NAME}"
        cp -r "$TARGET_DIR/." "$LOCAL_TEMP_DIR/"
        
        echo "# 1/3: FLAC変換中..."
        find "$LOCAL_TEMP_DIR" -type f \( -iname "*.wav" -o -iname "*.aiff" \) -exec sh -c 'flac --silent --force "$1" -o "${1%.*}.flac" && rm "$1"' _ {} \;
        echo "50"

        echo "# 2/3: 7z暗号化中..."
        cd "$LOCAL_TEMP_DIR" || exit
        7z a $P_ARG -mhe=off $V_ARG -mx=0 -mmt=on "${LOCAL_WORK_ROOT}/${OUTPUT_BASE_NAME}.7z" . -y > /dev/null
        echo "90"

        echo "# 3/3: 保存先へ移動中..."
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
                    ((COUNTER++))
                done
                DEST_NAME="${BASE}(${COUNTER}).${EXT}"
            fi
            mv "$f" "${LOCAL_ARCHIVE_DIR}/${DEST_NAME}"
        done
        rm -rf "$LOCAL_WORK_ROOT"
        echo "100"
    ) | zenity --progress --title="バックアップ中" --auto-close --pulsate
}

# --- 6. 実行 ---
for DIR in "${TARGET_LIST[@]}"; do
    process_backup "$DIR"
done

# --- 7. 最終ダイアログ ---
MSG="処理が完了しました。\n\n保存先: ${LOCAL_ARCHIVE_DIR}"
[ -s "$DUP_LOG_FILE" ] && MSG="${MSG}\n\n【重複あり】連番を付与しました：\n$(cat "$DUP_LOG_FILE")"
rm -f "$DUP_LOG_FILE"
zenity --info --title="完了" --text="$MSG"
