#!/bin/bash

# ==============================================================================
# Script Name: setup-kvm-coexistence.sh
# Description: KVM独占解除設定。
#              ダブルクリック実行時の自動ターミナル起動、sudo昇格、
#              および実行後のウィンドウ保持機能を統合した決定版。
# Version:     1.4.0
# Author:      Gemini Assistant
# ==============================================================================

# 1. ターミナルで実行されていない場合に、強制的にターミナルを立ち上げて再実行する
if [ ! -t 0 ]; then
  x-terminal-emulator -e "bash \"$0\""
  exit 0
fi

# 2. root権限（sudo）がない場合、sudoをつけて自分自身を再実行する
if [ "$EUID" -ne 0 ]; then
  echo "------------------------------------------------------------"
  echo " 設定変更には管理者権限が必要です。パスワードを入力してください。"
  echo "------------------------------------------------------------"
  sudo bash "$0" "$@"
  
  # 管理者側プロセスの終了後、この親プロセスで入力を待機してウィンドウを維持する
  echo ""
  echo "============================================================"
  echo " 処理が終了しました。内容を確認してください。"
  echo " Enterキーを押すとこのウィンドウを閉じます。"
  echo "============================================================"
  read dummy
  exit 0
fi

# --- ここから下は管理者権限(root)で実行される ---

echo "--- KVM共存設定 (Version 1.4.0) を開始します ---"

# 3. 設定ファイルの作成
CONF_FILE="/etc/modprobe.d/kvm.conf"
{
    echo "# KVM coexistence settings"
    echo "options kvm enable_virt_at_load=0"
} > "$CONF_FILE"

# 4. CPU（Intel/AMD）に応じたモジュール設定の追加
if grep -q "Intel" /proc/cpuinfo; then
    echo "options kvm_intel enable_virt_at_load=0" >> "$CONF_FILE"
    echo "[1/2] Intel CPU用の設定を $CONF_FILE に追加しました。"
else
    echo "options kvm_amd enable_virt_at_load=0" >> "$CONF_FILE"
    echo "[1/2] AMD CPU用の設定を $CONF_FILE に追加しました。"
fi

# 5. カーネルイメージ（initramfs）の更新
echo "[2/2] 設定をシステムに反映中(initramfs)..."
echo "      (数分かかる場合がありますが、そのままお待ちください)"

if update-initramfs -u; then
    echo ""
    echo "★ 設定が正常に完了しました！"
    echo "設定を反映させるために、OSを再起動してください。"
else
    echo ""
    echo "エラー: initramfsの更新に失敗しました。"
fi

exit 0
