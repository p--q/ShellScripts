#!/bin/bash

# ==============================================================================
# Script Name: setup-kvm-coexistence.sh
# Description: KVM独占解除設定。Nemoからの実行でも確実にウィンドウを残します。
# Version:     1.2.0
# ==============================================================================

# 1. ターミナルで実行されていない場合に、強制的にターミナルを立ち上げて再実行する
if [ ! -t 0 ]; then
  # ターミナルエミュレータ（Cinnamon標準のgnome-terminal等）で自身を起動
  x-terminal-emulator -e "$0"
  exit 0
fi

# 2. root権限チェック
if [ "$EUID" -ne 0 ]; then
  echo "------------------------------------------------------------"
  echo "エラー: このスクリプトは sudo をつけて実行してください。"
  echo "------------------------------------------------------------"
  echo "設定を中断しました。Enterキーを押すと終了します..."
  read dummy
  exit 1
fi

echo "--- KVM共存設定 (Version 1.2.0) を開始します ---"

# 3. 設定ファイルの作成
CONF_FILE="/etc/modprobe.d/kvm.conf"
{
    echo "# KVM coexistence settings"
    echo "options kvm enable_virt_at_load=0"
} > "$CONF_FILE"

# CPUに応じた追加設定
if grep -q "Intel" /proc/cpuinfo; then
    echo "options kvm_intel enable_virt_at_load=0" >> "$CONF_FILE"
    echo "[1/2] Intel CPU用の設定を追加。"
else
    echo "options kvm_amd enable_virt_at_load=0" >> "$CONF_FILE"
    echo "[1/2] AMD CPU用の設定を追加。"
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

echo "------------------------------------------------------------"
echo "処理が終了しました。このウィンドウの内容を確認してください。"
echo "Enterキーを押すとこのウィンドウを閉じます..."
echo "------------------------------------------------------------"

# 確実に停止させるためのread
read dummy
exit 0
