#!/bin/bash

# ==============================================================================
# Script Name: setup-kvm-coexistence.sh
# Description: KVM独占解除設定。
#              ダブルクリック実行時に自動でターミナルを開き、sudo昇格を行います。
# Version:     1.3.0
# ==============================================================================

# 1. ターミナルで実行されていない場合に、強制的にターミナルを立ち上げて再実行する
if [ ! -t 0 ]; then
  x-terminal-emulator -e "bash \"$0\""
  exit 0
fi

# 2. root権限（sudo）がない場合、sudoをつけて自分自身を再実行する
if [ "$EUID" -ne 0 ]; then
  echo "設定変更には管理者権限が必要です。パスワードを入力してください。"
  # sudo で自分自身 ($0) を実行。引数があればそれも引き継ぐ ($@)
  sudo bash "$0" "$@"
  
  # sudo側の実行が終わったら、この(権限のない)プロセスも終了を確認して止める
  echo ""
  echo "------------------------------------------------------------"
  echo "管理者セッションが終了しました。"
  echo "Enterキーを押すとこのウィンドウを閉じます..."
  read dummy
  exit 0
fi

# --- ここから下は管理者権限(root)で実行される ---

echo "--- KVM共存設定 (Version 1.3.0) を開始します ---"

# 3. 設定ファイルの作成
CONF_FILE="/etc/modprobe.d/kvm.conf"
{
    echo "# KVM coexistence settings"
    echo "options kvm enable_virt_at_load=0"
} > "$CONF_FILE"

# CPUに応じた追加設定
if grep -q "Intel" /proc/cpuinfo; then
    echo "options kvm_intel enable_virt_at_load=0" >> "$CONF_FILE"
    echo "[1/2] Intel CPU用の設定を追加しました。"
else
    echo "options kvm_amd enable_virt_at_load=0" >> "$CONF_FILE"
    echo "[1/2] AMD CPU用の設定を追加しました。"
fi

# 4. カーネルイメージの更新
echo "[2/2] 設定をシステムに反映中(initramfs)..."
if update-initramfs -u; then
    echo ""
    echo "★ 設定が正常に完了しました！"
    echo "再起動後に有効になります。"
else
    echo "エラー: 設定の反映に失敗しました。"
fi

exit 0
