#!/bin/bash
# ==============================================================================
# Script Name: flac-7z-backup.sh
# Version:     3.1.1 (Recursive Processing & NAS Picker)
# ==============================================================================

# 1. 依存チェック
for tool in "zenity" "7z" "flac" "gio"; do
    command -v "$tool" &> /dev/null || { zenity --error --text="$tool が見つかりません"; exit 1; }
done

# 2. ターゲット取得 (Nemoからの受け取り、失敗時はダイアログ)
RAW_INPUTS="$NEMO_SCRIPT_SELECTED_FILE_PATHS"
[ -z "$RAW_INPUTS" ] && RAW_INPUTS="$@"

TARGET_LIST=()
while IFS= read -r line; do
    [ -z "$line" ] && continue
    TARGET_LIST+=("$line")
done <<< "$(echo -e "$RAW_INPUTS")"

# フォルダ選択ダイアログへのフォールバック
if [ ${#TARGET_LIST[@]} -eq 0 ]; then
    TARGET_DIRS=$(zenity --file-selection --directory --multiple --separator="|" --title="NAS上の処理したいフォルダを選択してください")
    [ -z "$TARGET_DIRS" ] && exit
    IFS="|" read -ra TARGET_LIST <<< "$TARGET_DIRS"
fi

# 3. 設定入力パネル
CONFIG=$(zenity --forms --title="NAS Backup v3.1.1" \
    --text="選択されたフォルダを再帰的に処理します。" \
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

# 4. 処理実行
for TARGET in "${TARGET_LIST[@]}"; do
    DIR_NAME=$(basename "$TARGET")
    # 作業用一時フォルダ
    WORK_ROOT="${HOME}/.backup_temp_$(date +%s)"
    mkdir -p "$WORK_ROOT"

    (
        echo "# 1/3: NASからローカルへコピー中..."
        # フォルダごとコピー (再帰的)
        gio copy -r "$TARGET" "$WORK_ROOT/"
        echo "30"

        # コピーされた実体ディレクトリを特定
        COPIED_DIR=$(find "$WORK_ROOT" -maxdepth 1 -mindepth 1 -type d | head -n 1)
        [ -z "$COPIED_DIR" ] && exit

        echo "# 2/3: 全サブフォルダの音声を変換中..."
        # 【再帰的処理】サブディレクトリを含め、すべてのWAV/AIFFをFLACへ変換
        find "$COPIED_DIR" -type f \( -iname "*.wav" -o -iname "*.aiff" \) -exec sh -c '
            for file do
                flac --silent --force "$file" -o "${file%.*}.flac" && rm "$file"
            done
        ' _ {} +
        echo "70"

        echo "# 3/3: 7z暗号化中..."
        cd "$COPIED_DIR" || exit
        # 階層構造を維持して圧縮
        7z a $P_ARG -mhe=off $V_ARG -mx=0 -mmt=on "${WORK_ROOT}/${DIR_NAME}${SUFFIX}.7z" . -y > /dev/null
        
        # 保存先へ移動
        mv "${WORK_ROOT}/${DIR_NAME}${SUFFIX}.7z"* "$LOCAL_ARCHIVE_DIR/"
        
        # 一時ファイルの削除
        rm -rf "$WORK_ROOT"
        echo "100"
    ) | zenity --progress --title="一括処理中: $DIR_NAME" --auto-close --pulsate
done

zenity --info --title="完了" --text="すべての
