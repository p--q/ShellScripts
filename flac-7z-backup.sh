#!/bin/bash
# v2.1.7 (Nemo Action 専用版)

# 引数チェック（Nemo Actionから渡されるパス）
if [ $# -eq 0 ]; then
    zenity --error --text="対象フォルダが渡されませんでした。"
    exit 1
fi

# 依存チェック
for tool in "zenity" "7z" "flac"; do
    command -v "$tool" &> /dev/null || { zenity --error --text="$tool が未インストールです"; exit 1; }
done

# 設定入力
CONFIG=$(zenity --forms --title="NAS Backup v2.1.7" \
    --add-entry="接尾辞" --add-entry="分割容量" \
    --add-password="パスワード" --add-password="確認" --separator=",")
[ $? -ne 0 ] && exit

SUFFIX=$(echo "$CONFIG" | cut -d',' -f1)
SPLIT_SIZE=$(echo "$CONFIG" | cut -d',' -f2)
PASS1=$(echo "$CONFIG" | cut -d',' -f3)
PASS2=$(echo "$CONFIG" | cut -d',' -f4)
[ "$PASS1" != "$PASS2" ] && { zenity --error --text="不一致"; exit 1; }

V_ARG=""; [ -n "$SPLIT_SIZE" ] && V_ARG="-v${SPLIT_SIZE}"
P_ARG=""; [ -n "$PASS1" ] && P_ARG="-p${PASS1}"
LOCAL_ARCHIVE_DIR="${HOME}/Backup_Archives"
mkdir -p "$LOCAL_ARCHIVE_DIR"
DUP_LOG=$(mktemp)

# 処理ループ
for TARGET in "$@"; do
    [ ! -d "$TARGET" ] && continue
    DIR_NAME=$(basename "$TARGET")
    WORK_ROOT="${HOME}/.backup_temp_$(date +%s)"
    TEMP_DIR="${WORK_ROOT}/${DIR_NAME}"
    mkdir -p "$TEMP_DIR"

    (
        echo "# NASからコピー中..."
        cp -r "$TARGET/." "$TEMP_DIR/"
        echo "30"; echo "# FLAC変換中..."
        find "$TEMP_DIR" -type f \( -iname "*.wav" -o -iname "*.aiff" \) -exec sh -c 'flac --silent --force "$1" -o "${1%.*}.flac" && rm "$1"' _ {} \;
        echo "60"; echo "# 暗号化中..."
        cd "$TEMP_DIR" && 7z a $P_ARG -mhe=off $V_ARG -mx=0 "${WORK_ROOT}/${DIR_NAME}${SUFFIX}.7z" . > /dev/null
        echo "90"; echo "# 保存先へ移動中..."
        for f in "${WORK_ROOT}/${DIR_NAME}${SUFFIX}.7z"*; do
            D_NAME=$(basename "$f")
            if [ -e "${LOCAL_ARCHIVE_DIR}/$D_NAME" ]; then
                echo "$D_NAME" >> "$DUP_LOG"
                # (連番処理略: 簡略化のため)
            fi
            mv "$f" "${LOCAL_ARCHIVE_DIR}/"
        done
        rm -rf "$WORK_ROOT"
        echo "100"
    ) | zenity --progress --title="処理中: $DIR_NAME" --auto-close
done

zenity --info --text="完了\n保存先: $LOCAL_ARCHIVE_DIR"
rm -f "$DUP_LOG"
