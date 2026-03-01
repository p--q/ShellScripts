#!/bin/bash
# ==============================================================================
# Script Name: flac-7z-backup.sh
# Version:     1.9
# Description: NAS上のフォルダをローカルにコピーし、FLAC変換後に7zで暗号化。
#              ※7zは「無圧縮(ストア)」モードで動作し、高速にパスワード保護します。
#              成果物はローカル（~/Backup_Archives）に保存されます。
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

# 作業領域に必要な容量（コピー + 変換用バッファとして1.2倍）
BUFFERED_REQUIRED=$((TOTAL_REQUIRED_KB * 12 / 10))
FREE_SPACE=$(df -Pk "$HOME" | awk 'NR==2 {print $4}')

if [ "$FREE_SPACE" -lt "$BUFFERED_REQUIRED" ]; then
    REQUIRED_GB=$(echo "scale=2; $BUFFERED_REQUIRED/1024/1024" | bc)
    FREE_GB=$(echo "scale=2; $FREE_SPACE/1024/1024" | bc)
    zenity --error --text="容量不足です。\n要求: ${REQUIRED_GB} GB / 空き: ${FREE_GB} GB"
    exit 1
fi

# --- 4. 設定入力パネル ---
CONFIG=$(zenity --forms --title="flac-7z-backup v1.9" \
    --text="FLAC変換後、無圧縮7zで高速にパスワード保護を行います。" \
    --add-combo="1. オーディオをFLACに変換するか [既定: yes]" --combo-values="yes|no" \
    --add-entry="2. 分割容量 (例: 4400m) [既定: 4400m]" \
    --add-entry="3. ファイル名に付加する接尾辞[既定: '']" \
    --add-password="4. パスワード" \
    --add-password="5. パスワード（確認）" \
    --separator=",")

[ $? -ne 0 ] || [ -z "$CONFIG" ] && exit

# パース
DO_FLAC_RAW=$(echo "$CONFIG" | cut -d',' -f1)
SPLIT_SIZE_RAW=$(echo "$CONFIG" | cut -d',' -f2); SPLIT_SIZE=${SPLIT_SIZE_RAW:-4400m}
SUFFIX=$(echo "$CONFIG" | cut -d',' -f3)
PASS1=$(echo "$CONFIG" | cut -d',' -f4)
PASS2=$(echo "$CONFIG" | cut -d',' -f5)

[ "$DO_FLAC_RAW" != "no" ] && DO_FLAC="yes" || DO_FLAC="no"
[ "$PASS1" != "$PASS2" ] && { zenity --error --text="パスワード不一致"; exit 1; }
P_ARG=""; [ -n "$PASS1" ] && P_ARG="-p${PASS1}"

# ローカル保存用フォルダ作成
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
        # 1. NASからローカルへコピー
        mapfile -t ALL_FILES < <(cd "$ABS_TARGET_DIR" && find . -type f)
        TOTAL_FILES=${#ALL_FILES[@]}
        CUR_FILES=0
        for f in "${ALL_FILES[@]}"; do
            echo "# 取り込み中: $f"
            mkdir -p "$(dirname "$LOCAL_TEMP_DIR/$f")"
            cp "$ABS_TARGET_DIR/$f" "$LOCAL_TEMP_DIR/$f"
            CUR_FILES=$((CUR_FILES + 1))
            echo "$((CUR_FILES * 20 / TOTAL_FILES))"
        done

        # 2. FLAC変換
        if [ "$DO_FLAC" = "yes" ]; then
            echo "# FLAC変換中..."
            mapfile -t AUDIO_FILES < <(find "$LOCAL_TEMP_DIR" -type f \( -iname "*.wav" -o -iname "*.aiff" \))
            TOTAL_A=${#AUDIO_FILES[@]}
            [ $TOTAL_A -eq 0 ] && TOTAL_A=1
            COUNT_A=0
            for file in "${AUDIO_FILES[@]}"; do
                flac --silent --force "$file" -o "${file%.*}.flac" &> /dev/null && rm "$file"
                COUNT_A=$((COUNT_A + 1))
                echo "$((20 + COUNT_A * 40 / TOTAL_A))"
            done
        fi

        # 3. 7z暗号化 (無圧縮モード: -mx=0)
        echo "# 7z暗号化中 (無圧縮高速モード)..."
        cd "$LOCAL_TEMP_DIR" || exit
        # -mhe=on でヘッダーも暗号化（ファイル名も見えなくなります）
        7z a -mhe=on $P_ARG -v"${SPLIT_SIZE}" -mx=0 -mmt=on "${LOCAL_WORK_ROOT}/out.7z" . -y > /dev/null
        echo "85"

        # 4. 保存先フォルダへ転送
        echo "# アーカイブを保存中..."
        cd "$LOCAL_WORK_ROOT" || exit
        mapfile -t OUT_7Z < <(ls out.7z*)
        TOTAL_OUT=${#OUT_7Z[@]}
        COUNT_OUT=0
        for f in "${OUT_7Z[@]}"; do
            DEST_NAME=$(echo "$f" | sed "s/out.7z/${OUTPUT_BASE_NAME}/")
            cp "$f" "${LOCAL_ARCHIVE_DIR}/${DEST_NAME}"
            COUNT_OUT=$((COUNT_OUT + 1))
            echo "$((85 + COUNT_OUT * 15 / TOTAL_OUT))"
        done

        # 後片付け
        rm -rf "$LOCAL_WORK_ROOT"
        echo "100"
    ) | zenity --progress --title="処理中: $DIR_NAME" --auto-close --pulsate
done

zenity --info --title="完了" --text="処理が完了しました。\n\n【保存先】\n${LOCAL_ARCHIVE_DIR}"
