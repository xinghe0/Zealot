#!/bin/bash

# GitHub 仓库创建和推送脚本
# 使用前请确保已安装 GitHub CLI: brew install gh

set -e

echo "🚀 Zealot GitHub 仓库设置脚本"
echo "================================"

# 检查是否安装了 GitHub CLI
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI 未安装"
    echo "请先安装: brew install gh"
    echo "或者手动在 https://github.com 创建仓库"
    exit 1
fi

# 检查是否已登录
if ! gh auth status &> /dev/null; then
    echo "🔐 请先登录 GitHub CLI"
    gh auth login
fi

# 获取仓库名称
read -p "📝 请输入仓库名称 (默认: zealot-deployment): " REPO_NAME
REPO_NAME=${REPO_NAME:-zealot-deployment}

# 获取仓库描述
REPO_DESC="Zealot mobile app distribution platform with Docker deployment"

echo "📦 创建私人仓库: $REPO_NAME"

# 创建私人仓库
gh repo create "$REPO_NAME" \
    --private \
    --description "$REPO_DESC" \
    --confirm

# 添加远程仓库
echo "🔗 添加远程仓库"
git remote add origin "https://github.com/$(gh api user --jq .login)/$REPO_NAME.git"

# 推送代码
echo "📤 推送代码到 GitHub"
git push -u origin main

echo "✅ 完成！"
echo "🌐 仓库地址: https://github.com/$(gh api user --jq .login)/$REPO_NAME"
echo ""
echo "🎉 您的 Zealot 项目已成功上传到 GitHub 私人仓库！"