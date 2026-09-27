#!/bin/bash

echo "🚀 Dify MCP Bridge 安装脚本"
echo "================================"

# 检查 Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 未安装，请先安装 Python 3.8+"
    exit 1
fi

echo "✅ Python 3 已安装: $(python3 --version)"

# 创建虚拟环境
    echo "🔧 创建虚拟环境..."
python3 -m venv .venv
source .venv/bin/activate
    echo "✅ 虚拟环境已激活"

# 安装依赖
echo "📦 安装 Python 依赖..."
pip install -r requirements.txt

if [ $? -eq 0 ]; then
    echo "✅ 依赖安装成功"
else
    echo "❌ 依赖安装失败"
    exit 1
fi

# 设置环境变量
if [ ! -f ".env" ]; then
    echo "🔧 创建环境配置..."
    cp env.example .env
    echo "✅ 环境配置文件已创建: .env"
    echo "💡 请根据需要编辑 .env 文件"
fi

echo ""
echo "🎉 安装完成！"
echo ""
echo "下一步："
echo "1. 配置环境变量: 编辑 .env 文件"
echo "2. 启动服务器: 使用 start.sh 脚本"
echo ""
echo "💡 连接测试将在 Dify 服务启动后自动执行" 