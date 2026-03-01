#!/bin/bash
# ==============================================================================
# Script Name: flac-7z-backup.sh
# Version:     3.2.0 (Stable Selection & Recursive & Duplicate Report)
# ==============================================================================

# 1. 依存チェック
for tool in "zenity" "7z" "flac"; do
    command -v "$tool" &> /dev/null || { zenity --error --text="$tool が見つかりません。"; exit 1; }
done

# 2. フォルダ選択 (NAS上のフォルダを直接選ぶ方式に戻しました)
TARGET_DIRS=$(zenity --file-selection --directory --multiple --separator="|" --title="NAS上の処理したいフォルダを選択してください")
[ $? -ne 0 ] || [ -z "$TARGET_DIRS" ] && exit

# 3. 設定入力
CONFIG=$(zenity --forms --title="NAS Backup v3.2.0" \
    --text="選択されたフォルダ内をサブフォルダまで含めて処理します。" \
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

[ "$PASS1" != "$PASS2" ] && { zenity --error --text="パスワード不一致"; exit 1; }

V_ARG=""; [ -n "$SPLIT_SIZE" ] && V_ARG="-v${SPLIT_SIZE}"
P_ARG=""; [ -n "$PASS1" ] && P_ARG="-p${PASS1}"

LOCAL_ARCHIVE_DIR="${HOME}/Backup_Archives"
mkdir -p "$LOCAL_ARCHIVE_DIR"
DUP_LOG_FILE=$(mktemp)

# 4. 処理ループ
IFS="|"
for TARGET in $TARGET_DIRS; do
    [ -z "$TARGET" ] && continue
    DIR_NAME=$(basename "$TARGET")
    WORK_ROOT="${HOME}/.backup_temp_$(date +%s)"
    mkdir -p "$WORK_ROOT"

    (
        echo "# 1/3: データをローカルへ取り込み中..."
        # cp -r でNASからローカルへコピー（安定性重視）
        cp -r "$TARGET" "$WORK_ROOT/"
        
        # コピーされた実体ディレクトリのパスを取得
        COPIED_DIR="${WORK_ROOT}/${DIR_NAME}"

        echo "# 2/3: サブディレクトリ含めFLAC変換中..."
        # 再帰的にすべてのWAV/AIFFを検索して変換
        find "$COPIED_DIR" -type f \( -iname "*.wav" -o -iname "*.aiff" \) -exec sh -c '
            for f do
                echo "# 変換中: $(basename "$f")"
                flac --silent --force "$f" -o "${f%.*}.flac" && rm "$f"
            done
        ' _ {} +

        echo "# 3/3: 7z暗号化 & 移動中..."
        cd "$COPIED_DIR" || exit
        7z a $P_ARG -mhe=off $V_ARG -mx=0 -mmt=on "${WORK_ROOT}/${DIR_NAME}${SUFFIX}.7z" . -y > /dev/null
        
        # 保存先へ移動 & 重複時の連番処理
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
    ) | zenity --progress --title="バックアップ中: $DIR_NAME" --auto-close --pulsate
done

# 5. 最終報告
MSG="すべての処理が完了しました。\n\n保存先: ${LOCAL_ARCHIVE_DIR}"
if [ -s "$DUP_LOG_FILE" ]; then
    DUPS=$(cat "$DUP_LOG_FILE" | sort -u)
    MSG="${MSG}\n\n【注意】以下のファイルは既に存在していたため、連番を付与しました：\n${DUPS}"
fi

rm -f "$DUP_LOG_FILE"
zenity --info --title="完了" --text="$MSG"
