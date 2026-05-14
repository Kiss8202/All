#!/bin/bash

# 推送脚本 - 将代码上传到 Kiss8202/All 仓库
# 使用方法: ./push-to-all-repo.sh <your-personal-access-token>

if [[ $# -lt 1 ]]; then
    echo "用法: $0 <github-personal-access-token>"
    echo ""
    echo "请先在 https://github.com/settings/tokens 创建一个新的 token (需要 repo 权限)"
    exit 1
fi

TOKEN=$1
REPO="Kiss8202/All"

cd /workspace/All

echo "正在上传到 GitHub: $REPO"

# 设置远程仓库 URL（包含 token）
git remote set-url origin "https://${TOKEN}@github.com/${REPO}.git"

# 推送
git push -u origin main

if [[ $? -eq 0 ]]; then
    echo "✅ 上传成功!"
    echo "访问: https://github.com/$REPO"
else
    echo "❌ 上传失败，请检查 token 是否正确"
fi
