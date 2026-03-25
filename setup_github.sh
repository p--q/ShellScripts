#!/bin/bash

# ==============================================================================
# File Name:    setup_github.sh
# Version:      1.1.0
# Description:  Debian Cinnamon環境向け GitHub初期設定・Lazygit導入・SSH鍵生成スクリプト
#               - Gitのユーザー名とメールアドレスのグローバル設定
#               - 最新版Lazygitの自動インストール
#               - SSHキー(Ed25519)の生成とエージェントへの登録
# ==============================================================================

# --- ユーザー情報の入力 ---
echo "GitHubの設定を開始します。"
read -p "GitHubのユーザー名を入力してください: " GH_USER
read -p "GitHubのメールアドレスを入力してください: " GH_EMAIL

# 1. Gitの基本設定 (コミット署名用)
echo "--- Setting up Git Config ---"
git config --global user.name "$GH_USER"
git config --global user.email "$GH_EMAIL"
git config --global init.defaultBranch main
echo "Git config updated (User: $GH_USER, Email: $GH_EMAIL)."

# 2. Lazygitのインストール
echo "--- Installing Lazygit ---"
# 依存ツールの確認（curl, grep, tar）
sudo apt update && sudo apt install -y curl grep tar
LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
tar xf lazygit.tar.gz lazygit
sudo install lazygit /usr/local/bin
rm lazygit.tar.gz lazygit
echo "Lazygit v${LAZYGIT_VERSION} installation complete."

# 3. SSH鍵の生成
echo "--- Generating SSH Key ---"
SSH_DIR="$HOME/.ssh"
KEY_FILE="$SSH_DIR/id_ed25519"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

if [ -f "$KEY_FILE" ]; then
    echo "既存のSSH鍵が見つかりました。生成をスキップします。"
else
    # メールアドレスをコメントとして埋め込み
    ssh-keygen -t ed25519 -N "" -f "$KEY_FILE" -C "$GH_EMAIL"
    echo "SSH key (Ed25519) generated."
fi

# SSHエージェントに登録（再起動後も有効にするには別途設定が必要ですが、このセッションで有効化します）
eval "$(ssh-agent -s)"
ssh-add "$KEY_FILE"

# 4. 完了報告と公開鍵の表示
echo "-------------------------------------------------------"
echo "すべてのセットアップが完了しました！"
echo "-------------------------------------------------------"
echo "【重要】以下の『公開鍵』をコピーして、GitHubに登録してください。"
echo "登録先URL: https://github.com/settings/keys"
echo "-------------------------------------------------------"
cat "${KEY_FILE}.pub"
echo "-------------------------------------------------------"
echo "登録後、以下のコマンドで接続テストを行ってください:"
echo "ssh -T git@github.com"
