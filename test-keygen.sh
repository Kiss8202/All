#!/bin/bash
# 测试 sing-box 密钥生成格式

echo "=== 测试 sing-box reality-keypair 命令格式 ==="

# 检查是否有 sing-box
if ! command -v sing-box &>/dev/null; then
    echo "sing-box 未安装，无法测试"
    exit 1
fi

echo "运行: sing-box generate reality-keypair"
echo "--- 输出 ---"
sing-box generate reality-keypair
echo "------------"

# 测试用一个临时脚本来模拟
echo ""
echo "=== 模拟密钥对生成 ==="
TEST_KEY="PrivateKey: test-private-key-12345
PublicKey: test-public-key-67890"
echo "模拟输出："
echo "$TEST_KEY"
echo ""

echo "--- 提取测试 ---"
echo "PrivateKey: $(echo "$TEST_KEY" | grep "PrivateKey:" | awk '{print $2}')"
echo "PublicKey: $(echo "$TEST_KEY" | grep "PublicKey:" | awk '{print $2}')"
