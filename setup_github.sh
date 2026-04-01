#!/bin/bash

# ==============================================================================
# File Name:    setup_github.sh
# Version:      2.0.0
# Description:  Debian Cinnamon向け GitHub CLI・Lazygit・SSH・Git設定 統合スクリプト
#               - GitHub CLI (gh) のインストール
#               - 最新版Lazygitの自動インストール
#               - Gitのユーザー名とメールアドレスのグローバル設定
#               - SSHキー(Ed25519)の生成
# ==============================================================================

set -e # エラーが発生した時点でスクリプトを終了

echo "GitHubの統合セットアップを開始します。"

# --- 1. 依存ツールのインストール ---
echo "--- Installing Dependencies ---"
sudo apt update
sudo apt install -y curl grep tar executable-notifier

# --- 2. GitHub CLI (gh) のインストール ---
echo "--- Installing GitHub CLI ---"
if ! command -v gh &> /dev/null; then
    sudo mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update
    sudo apt install gh -y
    echo "GitHub CLI installed."
else
    echo "GitHub CLI is already installed."
fi

# --- 3. Lazygitのインストール ---
echo "--- Installing Lazygit ---"
LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
tar xf lazygit.tar.gz lazygit
sudo install lazygit /usr/local/bin
rm lazygit.tar.gz lazygit
echo "Lazygit v${LAZYGIT_VERSION} installed."

# --- 4. Gitの基本設定 ---
echo "--- Setting up Git Config ---"
# 既存の設定があるか確認し、なければ入力を促す
CURRENT_USER=$(git config --global user.name || true)
CURRENT_EMAIL=$(git config --global user.email || true)

if [ -z "$CURRENT_USER" ]; then
    read -p "GitHubのユーザー名を入力してください: " GH_USER
    git config --global user.name "$GH_USER"
else
    echo "User name already set: $CURRENT_USER"
fi

if [ -z "$CURRENT_EMAIL" ]; then
    read -p "GitHubのメールアドレスを入力してください: " GH_EMAIL
    git config --global user.email "$GH_EMAIL"
else
    echo "Email already set: $CURRENT_EMAIL"
    GH_EMAIL=$CURRENT_EMAIL
fi

git config --global init.defaultBranch main

# --- 5. SSH鍵の生成 ---
echo "--- Generating SSH Key ---"
SSH_DIR="$HOME/.ssh"
KEY_FILE="$SSH_DIR/id_ed25519"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

if [ ! -f "$KEY_FILE" ]; then
    ssh-keygen -t ed25519 -N "" -f "$KEY_FILE" -C "$GH_EMAIL"
    echo "SSH key generated."
else
    echo "SSH key already exists."
fi

# --- 完了報告 ---
echo "-------------------------------------------------------"
echo "すべてのツールのインストールと基本設定が完了しました！"
echo "-------------------------------------------------------"
echo "最後に以下のコマンドを実行して、GitHubへの認証を行ってください。"
echo "※これによりSSH鍵も自動的にGitHubへ登録されます。"
echo ""
echo "  gh auth login"
echo ""
echo "設定手順:"
echo "1. What account do you want to log into? -> GitHub.com"
echo "2. What is your preferred protocol for Git operations? -> SSH"
echo "3. Upload your SSH public key to your GitHub account? -> Yes (既存の鍵を選択)"
echo "4. How would you like to authenticate GitHub CLI? -> Login with a web browser"
echo "-------------------------------------------------------"
