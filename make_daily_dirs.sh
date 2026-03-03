#!/bin/bash

# ==============================================================================
# File: make_daily_dirs.sh
# Version: 1.0.0
# Description: 2026年3月〜12月の特定日（日・金・祝日を除く）のフォルダを一括作成する。
#              フォルダ形式: YYYYMMDD
# ==============================================================================

# 2026年の祝日・振替休日リスト (YYYYMMDD)
HOLIDAYS=(
    "20260101" "20260112" "20260211" "20260223" "20260320"
    "20260429" "20260503" "20260504" "20260505" "20260506"
    "20260720" "20260811" "20260921" "20260922" "20260923"
    "20261012" "20261103" "20261123"
)

# 期間の設定
current_date="2026-03-01"
end_date="2026-12-31"

echo "処理を開始します..."

while [ "$current_date" != "$(date -I -d "$end_date + 1 day")" ]; do
    
    # 判定用データの抽出
    dir_name=$(date -d "$current_date" "+%Y%m%d")
    day_of_week=$(date -d "$current_date" "+%u") # 5=金, 7=日
    
    # 祝日フラグの初期化
    is_holiday=false
    for h in "${HOLIDAYS[@]}"; do
        if [ "$h" == "$dir_name" ]; then
            is_holiday=true
            break
        fi
    done

    # 【条件】日曜日(7)でない 且つ 金曜日(5)でない 且つ 祝日でない
    if [ "$day_of_week" != "7" ] && [ "$day_of_week" != "5" ] && [ "$is_holiday" = false ]; then
        if [ ! -d "$dir_name" ]; then
            mkdir "$dir_name"
            echo "Created: $dir_name"
        fi
    fi

    # カウントアップ
    current_date=$(date -I -d "$current_date + 1 day")
done

echo "すべての処理が完了しました。"
