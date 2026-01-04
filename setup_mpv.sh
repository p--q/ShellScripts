#!/bin/bash

# 1. mpvのインストール
echo "mpvをインストールしています..."
sudo apt update
sudo apt install -y mpv

# 2. 設定ディレクトリの作成
mkdir -p ~/.config/mpv

# 3. mpv.conf の作成
echo "設定ファイルを書き出しています..."

cat << EOF > ~/.config/mpv/mpv.conf
# スクリーンショットの保存先とファイル名テンプレート
screenshot-template=~/ピクチャ/%F_%wH%wM%wS%wT

# JPEGの画質設定 (100は最高品質)
screenshot-jpeg-quality=100
EOF

echo "------------------------------------------"
echo "完了しました！"
echo "~/.config/mpv/mpv.conf を作成しました。"
echo "Enterキーを押すとこのウィンドウを閉じます。"
echo "------------------------------------------"

# ここが重要：ユーザーがEnterを押すまで待機します
read
