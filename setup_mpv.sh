#!/bin/bash

# 1. mpvのインストール
echo "mpvをインストールしています..."
sudo apt update
sudo apt install -y mpv

# 2. 設定ディレクトリの作成
# -p オプションで、既に存在していてもエラーにならず、親ディレクトリも作成します
mkdir -p ~/.config/mpv

# 3. mpv.conf の作成と設定値の書き込み
# > は上書き（既存の設定を消して新しく作る）、>> は追記です。
# 今回は新規作成または全書き換えを想定して > を使用します。
echo "設定ファイルを書き出しています..."

cat << EOF > ~/.config/mpv/mpv.conf
# スクリーンショットの保存先とファイル名テンプレート
screenshot-template=~/ピクチャ/%F_%wH%wM%wS%wT

# JPEGの画質設定 (100は最高品質)
screenshot-jpeg-quality=100
EOF

echo "完了しました。 ~/.config/mpv/mpv.conf を作成しました。"
