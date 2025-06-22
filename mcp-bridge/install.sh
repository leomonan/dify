#!/bin/bash

echo "🚀 Dify MCP Bridge 安装脚本"
echo "================================"

# 检查 Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 未安装，请先安装 Python 3.8+"
    exit 1
fi

echo "✅ Python 3 已安装: $(python3 --version)"

# 创建虚拟环境（可选）
read -p "是否创建 Python 虚拟环境？ (y/N): " create_venv
if [[ $create_venv =~ ^[Yy]$ ]]; then
    echo "🔧 创建虚拟环境..."
    python3 -m venv venv
    source venv/bin/activate
    echo "✅ 虚拟环境已激活"
fi

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
echo "1. 配置环境变量: python setup_env.py"
echo "2. 运行测试: python test_connection.py"
echo "3. 启动服务器: python start_server.py"
echo ""
echo "💡 如果遇到问题，请查看 TROUBLESHOOTING.md"

# 询问是否配置环境
read -p "是否立即配置环境变量？ (y/N): " setup_env
if [[ $setup_env =~ ^[Yy]$ ]]; then
    echo "🔧 启动环境配置助手..."
    python setup_env.py
    
    # 如果配置成功，询问是否测试
    if [ $? -eq 0 ]; then
        read -p "是否立即运行连接测试？ (y/N): " run_test
        if [[ $run_test =~ ^[Yy]$ ]]; then
            echo "🧪 运行连接测试..."
            python test_connection.py
        fi
    fi
fi 