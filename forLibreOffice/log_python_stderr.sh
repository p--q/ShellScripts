#!/bin/bash

# ===== 端末を開いたまま実行させる仕組み =====
if [ -z "$IN_TERMINAL" ]; then
    IN_TERMINAL=1 exec x-terminal-emulator -e "$0" "$@"
fi

# ===== 実際の処理 =====
LO="/opt/libreoffice25.8/program"
LOG="$HOME/lo-python-error.log"

echo "LibreOffice Calc を起動し、Python マクロの stderr を $LOG に記録します"
echo "----------------------------------------------"

"$LO/soffice" --calc 2>&1 | tee "$LOG"

echo
echo "ログは $LOG に保存されています。"
read -p "Enter を押すと端末を閉じます"

