#!/bin/bash

# ===== 端末を開いたまま実行させる仕組み =====
if [ -z "$IN_TERMINAL" ]; then
    IN_TERMINAL=1 exec x-terminal-emulator -e "$0" "$@"
fi

# ===== 実際の処理 =====
LO="/opt/libreoffice25.8/program"
LOG="$HOME/lo-ui.log"

export SAL_LOG="+INFO.vcl"
export SAL_USE_VCLPLUGIN=gtk3

echo "LibreOffice UI の SAL_LOG を $LOG に記録します"
echo "----------------------------------------------"

"$LO/soffice" --calc 2>&1 | tee "$LOG"

echo
echo "ログは $LOG に保存されています。"
read -p "Enter を押すと端末を閉じます"
