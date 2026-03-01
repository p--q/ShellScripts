#!/bin/bash
# ==============================================================================
# Script Name: flac-7z-backup.sh
# Version:     3.1.0 (The Final Solution - Force Detection)
# ==============================================================================

# 1. 依存チェック
for tool in "zenity" "7z" "flac"; do
    command -v "$tool" &> /dev/null || { zenity --error --text="$tool がありません"; exit 1; }
done

# 2. ターゲット取得の最終兵器
# 引数が空の場合、Nemoが一時的にマウントしているGVFSディレクトリを直接スキャンします
RAW_INPUTS="$NEMO_SCRIPT_SELECTED_FILE_PATHS"
[ -z "$RAW_INPUTS" ] && RAW_INPUTS="$@"

# 【重要】もしNemoが何も渡してくれない場合、現在Nemoで開いている「場所」を環境変数から取得
if [ -z "$RAW_INPUTS" ] && [ -n "$NEMO_SCRIPT_CURRENT_URI" ]; then
    # URI (smb://...) を ローカルパス (/run/user/.../gvfs/...) に変換
    RAW_INPUTS=$(gio mount -l | grep -A 5 "mount" | grep "default_location" | cut -d= -f2 | sed 's|^file://||' | python3 -c "import sys, urllib.parse; print(urllib.parse.unquote(sys.stdin.read().strip()))")
fi

# パスリストの作成
TARGET_LIST=()
while IFS= read -r line; do
    [ -z "$line" ] && continue
    # パスが smb:// の場合は gio mount を使って解釈
    TARGET_LIST+=("$line")
done <<< "$(echo -e "$RAW_INPUTS")"

# 3. エラー時の最終手段：フォルダ選択ダイアログを表示（NAS対応版）
if [ ${#TARGET_LIST[@]} -eq 0 ]; then
    # 通常のダイアログではNASが見えない場合があるため、
    # ユーザーに「ネットワーク」から手動で選んでもらうよう誘導
    TARGET_DIRS=$(zenity --file-selection --directory --multiple --separator="|" --title="NAS上のフォルダを直接選択してください")
    [ -z "$TARGET_DIRS" ] && exit
    IFS="|" read -ra TARGET_LIST <<< "$TARGET_DIRS"
fi

# 4. 設定入力パネル（ここが出れば成功）
CONFIG=$(zenity --forms --title="NAS Backup v3.1.0" \
    --text="NAS上の音源を処理します。" \
    --add-entry="接尾辞" --add-entry="分割容量" \
    --add-password="パスワード" --add-password="確認" --separator=",")

[ $? -ne 0 ] || [ -z "$CONFIG" ] && exit

SUFFIX=$(echo "$CONFIG" | cut -d',' -f1)
SPLIT_SIZE=$(echo "$CONFIG" | cut -d',' -f2)
PASS1=$(echo "$CONFIG" | cut -d',' -f3)
PASS2=$(echo "$CONFIG" | cut -d',' -f4)

V_ARG=""; [ -n "$SPLIT_SIZE" ] && V_ARG="-v${SPLIT_SIZE}"
P_ARG=""; [ -n "$PASS1" ] && P_ARG="-p${PASS1}"

LOCAL_ARCHIVE_DIR="${HOME}/Backup_Archives"
mkdir -p "$LOCAL_ARCHIVE_DIR"

# 5. 処理実行
for TARGET in "${TARGET_LIST[@]}"; do
    DIR_NAME=$(basename "$TARGET")
    WORK_ROOT="${HOME}/.backup_temp_$(date +%s)"
    mkdir -p "$WORK_ROOT"

    (
        echo "# NASからデータを吸い出し中..."
        # gio copy は NAS の URI も パス も両方扱えます
        gio copy -r "$TARGET" "$WORK_ROOT/"
        echo "40"

        # ローカルにコピーした後のフォルダ名を特定
        COPIED_DIR=$(find "$WORK_ROOT" -maxdepth 1 -type d | tail -n 1)

        echo "# 音声ファイルをFLACへ変換中..."
        find "$COPIED_DIR" -type f \( -iname "*.wav" -o -iname "*.aiff" \) -exec sh -c 'flac --silent --force "$1" -o "${1%.*}.flac" && rm "$1"' _ {} \;
        echo "70"

        echo "# 暗号化中..."
        cd "$COPIED_DIR" || exit
        7z a $P_ARG -mhe=off $V_ARG -mx=0 "${WORK_ROOT}/${DIR_NAME}${SUFFIX}.7z" . -y > /dev/null
        
        mv "${WORK_ROOT}/${DIR_NAME}${SUFFIX}.7z"* "$LOCAL_ARCHIVE_DIR/"
        rm -rf "$WORK_ROOT"
        echo "100"
    ) | zenity --progress --title="バックアップ中: $DIR_NAME" --auto-close --pulsate
done

zenity --info --title="完了" --text="処理完了\n保存先: $LOCAL_ARCHIVE_DIR"
