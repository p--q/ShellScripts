#!/bin/bash

LO="/opt/libreoffice25.8/program"
LOG="$HOME/lo-python-error.log"

echo "LibreOffice Calc を起動し、Python マクロの stderr を $LOG に記録します"

"$LO/soffice" --calc 2>&1 | tee "$LOG"
