#!/bin/bash
# ==============================================================================
# Script Name: flac-7z-backup.sh
# Version:     2.1.5 (NAS & GVfs Path Compatible)
# ==============================================================================

# --- 1. 依存ツールのチェック ---
for tool in "zenity" "7z" "flac" "python3"; do
    if ! command -v "$tool" &> /dev/null; then
        zenity --error --text="必要なツール ($tool) が見つかりません。"
        exit 1
    fi
done

# --- 2. ターゲットの取得 (NASの仮想パスをローカルパスへ変換) ---
# Nemoが渡す URI (smb://... や file:///...) を、Linuxが読み取れる実際の場所へ変換する関数
convert_path() {
    local input="$1"
    # Pythonを使用してURIデコードし、gvfsのローカルマウントポイントを探す
    python3 -c "
import sys, urllib.parse, os
uri = sys.stdin.read().strip()
# file:/// の除去
path = uri.replace('file://', '')
# %20 などのデコード
path = urllib.parse.unquote(path)

# もし smb:// などの場合は、GVfsのマウント先を探す
if '://' in path:
    # 一般的なLinuxでのGVfsマウント先
    user_id = os.getuid()
    gvfs_root = f'/run/user/{user_id}/gvfs'
    # smb-share:server=... のような形式をパスに変換する試みは複雑なため、
    # ここではNemoが環境変数で渡すフルパスを信じるロジックへ。
    print(path)
else:
    print(path)
" <<< "$input"
}

RAW_PATHS=""
# 手法A: Nemoのフルパス変数を優先 (これが最もNASのローカルパスに近い)
if [ -n "$NEMO_SCRIPT_SELECTED_FILE_PATHS" ]; then
    RAW_PATHS="$NEMO_SCRIPT_SELECTED_FILE_PATHS"
# 手法B: 引数をチェック
elif [ $# -gt 0 ]; then
    for arg in "$@"; do
        RAW_PATHS="${RAW_PATHS}${arg}\n"
    done
fi

TARGET_DIRS=""
OLD_IFS=$IFS
IFS=$'\n'
for line in $(echo -e "$RAW_PATHS"); do
    [ -z "$line" ] && continue
    
    # パスを正規化
    CLEAN_PATH=$(convert_path "$line")
    
    # NASの場合、標準の [ -d ] が効かないケースがあるため
    # 実在チェックを少し緩めるか、マウントポイントを考慮
    if [ -e "$CLEAN_PATH" ]; then
        TARGET_DIRS="${TARGET_DIRS}${CLEAN_PATH}|"
    fi
done
TARGET_DIRS="${TARGET_DIRS%|}"
IFS=$OLD_IFS

# 最終確認
if [ -z "$TARGET_DIRS" ]; then
    zenity --error --text="NAS上の対象フォルダを認識できませんでした。\nパス: $RAW_PATHS"
    exit 1
fi

# --- 3. 動的な空き容量チェック ---
# NAS上のファイルサイズ取得は時間がかかる場合があるため慎重に実行
TOTAL_REQUIRED_KB=$(du -sk "${TARGET_DIRS//|/ }" | awk '{sum+=$1} END {print sum}')
BUFFERED_REQUIRED=$((TOTAL_REQUIRED_KB * 11 / 10))
FREE_SPACE=$(df -Pk "$HOME" | awk 'NR==2 {print $4}')

if [ "$FREE_SPACE" -lt "$BUFFERED_REQUIRED" ]; then
    zenity --error --text="ローカル側の容量不足です。"
    exit 1
fi

# --- 4. 設定入力パネル ---
CONFIG=$(zenity --forms --title="flac-7z-backup v2.1.5" \
    --text="NAS上のフォルダを処理します。" \
    --add-entry="1. 接尾辞" \
    --add-entry="2. 分割容量 (例: 4400m)" \
    --add-
