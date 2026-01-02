#!/bin/bash

# ==============================================================================
# Script Name: setup-kvm-coexistence.sh
# Description: KVMによるCPU仮想化機能(VT-x/AMD-V)の起動時独占を解除し、
#              VirtualBoxやVMwareとAndroid Emulatorの共存を可能にします。
#              処理終了後にターミナルを開いたままにする待機処理付き。
# Version:     1.1.0
# Author:      Gemini Assistant
# ==============================================================================

# 1. 実行権限の確認（rootユーザーが必要）
if [ "$EUID" -ne 0 ]; then
  echo "------------------------------------------------------------"
  echo "エラー: このスクリプトは sudo をつけて実行してください。"
  echo "例: sudo ./setup-kvm-coexistence.sh"
  echo "------------------------------------------------------------"
  echo "Enterキーを押すと終了します..."
  read
  exit 1
fi

echo "--- KVM共存設定 (Version 1.1.0) を開始します ---"

# 2. 設定ファイルの作成
# enable_virt_at_load=0 により、KVMが必要になるまでCPUの仮想化機能をロックしません
CONF_FILE="/etc/modprobe.d/kvm.conf"
echo "# KVM coexistence settings" > $CONF_FILE
echo "options kvm enable_virt_at_load=0" >> $CONF_FILE

echo "[1/3] $CONF_FILE を作成/更新しました。"

# 3. CPU（Intel/AMD）に応じたモジュール設定の追加
if grep -q "Intel" /proc/cpuinfo; then
    echo "options kvm_intel enable_virt_at_load=0" >> $CONF_FILE
    echo "[2/3] Intel CPU用の設定を追加しました。"
else
    echo "options kvm_amd enable_virt_at_load=0" >> $CONF_FILE
    echo "[2/3] AMD CPU用の設定を追加しました。"
fi

# 4. カーネルイメージ（initramfs）の更新
# この作業により、OS起動時の早い段階から設定が反映されるようになります
echo "[3/3] カーネル設定(initramfs)を更新中..."
echo "      (数分かかる場合がありますが、そのままお待ちください)"

if update-initramfs -u; then
    echo ""
    echo "------------------------------------------------------------"
    echo "★ 設定が正常に完了しました！"
    echo "設定を反映させるために、システムを再起動してください。"
    echo "------------------------------------------------------------"
else
    echo ""
    echo "------------------------------------------------------------"
    echo "警告: initramfsの更新中にエラーが発生しました。"
    echo "------------------------------------------------------------"
fi

# 5. Nemoなどのファイルマネージャーから実行した際、結果を確認できるように待機する
echo ""
echo "処理が終了しました。このウィンドウの内容を確認してください。"
echo "Enterキーを押すとこのターミナルを閉じます..."
read

exit 0
