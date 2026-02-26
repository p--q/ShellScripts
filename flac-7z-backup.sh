#!/bin/bash
# ==============================================================================
# Script Name: flac-7z-backup.sh
# Description: NAS上のフォルダをローカルの作業領域に引き込み、
#              音源のFLAC変換と7z分割圧縮（パスワード保護対応）を行う。
#              処理後のアーカイブはNASとローカルの両方に保存される。
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

# --- 2. 空き容量の事前チェック (40GB以上必要) ---
# 単位はKB。40GB = 41943040 KB
FREE_SPACE=$(df -Pk "$HOME" | awk 'NR==2 {print $4}')
REQUIRED_SPACE=41943040
if [ "$FREE_SPACE" -lt "$REQUIRED_SPACE" ]; then
    zenity --error --text="内蔵ストレージの空き容量が不足しています。\n最低40GB必要ですが、現在の空きは $((FREE_SPACE / 1024 / 1024))GB です。"
    exit 1
fi

# --- 3. フォルダ選択 ---
TARGET_DIRS=$(zenity --file-selection --directory --multiple --separator="|" --title="NAS上のフォルダを選択してください")
[ $? -ne 0 ] || [ -z "$TARGET_DIRS" ] && exit

# --- 4. 設定入力パネル ---
CONFIG=$(zenity --forms --title="大容量対応バックアップ設定" \
    --text="PCの内蔵ストレージを作業領域に使用し、完了後はローカルにも保存します。" \
    --add-combo="1. オーディオをFLACに変換するか [既定: yes]" --combo-values="yes|no" \
    --add-entry="2. 7z圧縮レベル (0-9) [既定: 3]" \
    --add-entry="3. 分割容量 (例: 4400m) [既定: 4400m]" \
    --add-entry="4. ファイル名に付加する文字列[既定: '']" \
    --add-password="5. パスワード[既定: '']" \
    --add-password="6. パスワード（確認）" \
    --separator=",")

[ $? -ne 0 ] || [ -z "$CONFIG" ] && exit

# パース
DO_FLAC_RAW=$(echo "$CONFIG" | cut -d',' -f1)
COMP_LEVEL_INPUT=$(echo "$CONFIG" | cut -d',' -f2)
SPLIT_SIZE_RAW=$(echo "$CONFIG" | cut -d',' -f3); SPLIT_SIZE=${SPLIT_SIZE_RAW:-4400m}
SUFFIX=$(echo "$CONFIG" | cut -d',' -f4)
PASS1=$(echo "$CONFIG" | cut -d',' -f5)
PASS2=$(echo "$CONFIG" | cut -d',' -f6)

[ "$DO_FLAC_RAW" != "no" ] && DO_FLAC="yes" || DO_FLAC="no"
[ "$DO_FLAC" = "yes" ] && COMP_LEVEL=0 || COMP_LEVEL=${COMP_LEVEL_INPUT:-3}
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
    PARENT_DIR=$(dirname "$ABS_TARGET_DIR")
    OUTPUT_BASE_NAME="${DIR_NAME}${SUFFIX}.7z"

    LOCAL_WORK_ROOT="${HOME}/.backup_temp_work_$(date +%s)"
    LOCAL_TEMP_DIR="${LOCAL_WORK_ROOT}/${DIR_NAME}"
    mkdir -p "$LOCAL_TEMP_DIR"

    (
        echo "# 既存のアーカイブをクリーンアップ中..."
        rm -f "${PARENT_DIR}/${OUTPUT_BASE_NAME}"*

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

        # 3. 7z圧縮
        echo "# 7z圧縮中..."
        cd "$LOCAL_TEMP_DIR" || exit
        7z a -mhe=on $P_ARG -v"${SPLIT_SIZE}" -mx="${COMP_LEVEL}" -mmt=on "${LOCAL_WORK_ROOT}/out.7z" . -y > /dev/null
        echo "85"

        # 4. NASおよびローカル保存用フォルダへ転送
        echo "# ファイルを転送中..."
        cd "$LOCAL_WORK_ROOT" || exit
        mapfile -t OUT_7Z < <(ls out.7z*)
        TOTAL_OUT=${#OUT_7Z[@]}
        COUNT_OUT=0
        for f in "${OUT_7Z[@]}"; do
            DEST_NAME=$(echo "$f" | sed "s/out.7z/${OUTPUT_BASE_NAME}/")
            # NASへ書き戻し
            cp "$f" "${PARENT_DIR}/${DEST_NAME}"
            # ローカルにも残す
            cp "$f" "${LOCAL_ARCHIVE_DIR}/${DEST_NAME}"
            
            COUNT_OUT=$((COUNT_OUT + 1))
            echo "$((85 + COUNT_OUT * 14 / TOTAL_OUT))"
        done

        # 後片付け
        rm -rf "$LOCAL_WORK_ROOT"
        echo "100"
    ) | zenity --progress --title="処理中: $DIR_NAME" --auto-close --pulsate
done

zenity --info --title="完了" --text="処理が完了しました。\n\n【アーカイブの場所】\nNAS: 選択した各フォルダの親ディレクトリ\nローカル: ${LOCAL_ARCHIVE_DIR}"
