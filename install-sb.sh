#!/bin/bash
#
# 安装 sb 快捷命令
#

SCRIPT_URL="https://raw.githubusercontent.com/Kiss8202/All/main/main.sh"

echo "正在安装 sb 快捷命令..."

# 检查是否为 root
if [[ $EUID -ne 0 ]]; then
    echo "请使用 root 权限运行此脚本"
    exit 1
fi

# 创建 sb 命令
cat > /usr/local/bin/sb << 'EOF'
#!/bin/bash
#
# sb - Sing-Box 管理快捷命令
#

SCRIPT_URL="https://raw.githubusercontent.com/Kiss8202/All/main/main.sh"

# 如果本地有脚本，优先使用本地
if [[ -f /usr/local/sing-box-node/main.sh ]]; then
    bash /usr/local/sing-box-node/main.sh "$@"
else
    bash <(curl -fsSL "$SCRIPT_URL") "$@"
fi
EOF

chmod +x /usr/local/bin/sb

echo "✅ sb 快捷命令安装完成！"
echo "现在可以直接输入 'sb' 来启动管理脚本了！"
