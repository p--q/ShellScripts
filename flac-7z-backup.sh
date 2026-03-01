#!/bin/bash
# ==============================================================================
# Script Name: flac-7z-backup.sh
# Version:     3.0.0 (NAS / GVfs specialized)
# ==============================================================================

# --- 1. 依存ツールのチェック ---
for tool in "zenity" "7z" "flac" "gio"; do
    command -v "$tool" &> /dev/null || { zenity --error --text="$tool が見つかりません。"; exit 1; }
done

# --- 2. ターゲットの取得 (NAS URI対応) ---
# Nemoから渡されるパス（URI形式含む）を取得
RAW_INPUTS="$NEMO_SCRIPT_SELECTED_FILE_PATHS"
[ -z "$RAW_INPUTS" ] && RAW_INPUTS="$@"

# ターゲットを配列に格納
TARGET_LIST=()
while IFS= read -r line; do
    [ -z "$line" ] && continue
    TARGET_LIST+=("$line")
done <<< "$RAW_INPUTS"

if [ ${#TARGET_LIST[@]} -eq 0 ]; then
    zenity --error --text="対象フォルダを認識できませんでした。"
    exit 1
fi

# --- 3. 設定入力パネル ---
# 容量チェックの前に、まずパスワード等を聞く（NASだと容量計算に時間がかかるため）
CONFIG=$(zenity --forms --title="NAS Backup v3.0.0" \
    --text="NAS上のフォルダをローカルへ取り込み、FLAC変換・暗号化します。" \
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

# --- 4. メイン処理ループ ---
for TARGET_URI in "${TARGET_LIST[@]}"; do
    # フォルダ名を取得
    DIR_NAME=$(basename "$TARGET_URI")
    OUTPUT_BASE_NAME="${DIR_NAME}${SUFFIX}"
    
    # 作業用の一時場所
    LOCAL_WORK_ROOT="${HOME}/.backup_temp_$(date +%s)"
    LOCAL_TEMP_DIR="${LOCAL_WORK_ROOT}/${DIR_NAME}"
    mkdir -p "$LOCAL_TEMP_DIR"

    (
        echo "# 1/3: NASからデータを吸い出し中..."
        # 【重要】NAS(smb://)を直接扱える gio copy を使用
        gio copy -r "$TARGET_URI" "$LOCAL_WORK_ROOT/"
        echo "40"

        echo "# 2/3: 音声ファイルをFLACへ変換中..."
        find "$LOCAL_TEMP_DIR" -type f \( -iname "*.wav" -o -iname "*.aiff" \) -exec sh -c 'flac --silent --force "$1" -o "${1%.*}.flac" && rm "$1"' _ {} \;
        echo "70"

        echo "# 3/3: 7z暗号化 & 移動中..."
        cd "$LOCAL_TEMP_DIR" || exit
        7z a $P_ARG -mhe=off $V_ARG -mx=0 -mmt=on "${LOCAL_WORK_ROOT}/${OUTPUT_BASE_NAME}.7z" . -y > /dev/null
        
        # 最終場所へ移動（重複回避は簡易版）
        mv "${LOCAL_WORK_ROOT}/${OUTPUT_BASE_NAME}.7z"* "$LOCAL_ARCHIVE_DIR/"
        
        # 後片付け
        rm -rf "$LOCAL_WORK_ROOT"
        echo "100"
    ) | zenity --progress --title="処理中: $DIR_NAME" --auto-close --pulsate
done

zenity --info --title="完了" --text="処理が完了しました。\n保存先: $LOCAL_ARCHIVE_DIR"
