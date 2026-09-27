#!/bin/bash
# Dify MCP工具部署脚本
# 文件名: deploy.sh
# 描述: 部署Dify本地环境和MCP Bridge服务器
# 最后更新日期: 2025年6月23日星期一 10:13:16

# 获取scripts目录的绝对路径
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# 获取dify目录的绝对路径
DIFY_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
# 获取third-party目录的绝对路径
THIRD_PARTY_DIR="$( cd "$DIFY_DIR/.." && pwd )"
# 获取项目根目录的绝对路径
PROJECT_ROOT="$( cd "$THIRD_PARTY_DIR/../.." && pwd )"

# 默认参数
FORCE=false
VERBOSE=false
PARENT_CALL=false  # 新增：标识是否由父脚本调用

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --parent-call)  # 新增：父脚本调用标识
            PARENT_CALL=true
            shift
            ;;
        *)
            echo "未知选项: $1"
            shift
            ;;
    esac
done

# 导入统一工具库
source "$PROJECT_ROOT/scripts/lib/common_utils.sh"

# 验证工具加载成功
check_utils_loaded "deploy" || exit 1

# 初始化环境
init_deploy_env

# 显示部署信息
show_deploy_subproject_config "$DIFY_DIR" "Dify MCP工具"

# 如果是用户直接调用，初始化配置规则工具
if [ "$PARENT_CALL" = false ]; then
    # 加载配置规则工具
    if [ -f "$PROJECT_ROOT/scripts/lib/config_rules_utils.sh" ]; then
        source "$PROJECT_ROOT/scripts/lib/config_rules_utils.sh"
        if [ "$CONFIG_RULES_UTILS_LOADED" = "true" ]; then
            echo "✅ 配置规则工具加载成功"
            # 初始化配置规则文件
            init_config_rules_file
        else
            echo "⚠️ 配置规则工具加载失败"
        fi
    else
        echo "⚠️ 配置规则工具文件不存在"
    fi
fi

# 确保在正确的目录下
cd "$DIFY_DIR"

echo "🚀 开始部署 Dify MCP..."

# 指定使用Python 3.11版本, ！注意！不能使用3.12版本，会出现依赖问题
PYTHON_CMD="python3.11"

# 检查指定的Python版本
echo "🔍 检查Python环境..."
if ! command -v $PYTHON_CMD &> /dev/null; then
    echo "❌ $PYTHON_CMD 未安装或不在PATH中"
    echo "请安装Python 3.11或更高版本，命令："
    echo "brew install python@3.11  # macOS用户"
    exit 1
fi

PYTHON_VERSION=$($PYTHON_CMD --version 2>&1 | awk '{print $2}')
echo "✅ Python版本: $PYTHON_VERSION"

# 检查必要工具
echo "🔍 检查必要工具..."
# 检查uv包管理器
if ! command -v uv &> /dev/null; then
    echo "📦 安装uv包管理器..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    if [ $? -ne 0 ]; then
        echo "❌ uv安装失败"
        exit 1
    fi
    source $HOME/.cargo/env
fi
echo "✅ uv包管理器已安装"

# 检查Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker未安装，请先安装Docker"
    echo "macOS: brew install --cask docker"
    echo "Ubuntu: sudo apt install docker.io"
    exit 1
fi
echo "✅ Docker已安装"

# 检查Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose未安装，请先安装Docker Compose"
    echo "pip install docker-compose"
    exit 1
fi
echo "✅ Docker Compose已安装"

# 检查Node.js和pnpm
if ! command -v node &> /dev/null; then
    echo "❌ Node.js未安装，请先安装Node.js"
    echo "brew install node  # macOS用户"
    exit 1
fi

if ! command -v pnpm &> /dev/null; then
    echo "📦 安装pnpm..."
    npm install -g pnpm
    if [ $? -ne 0 ]; then
        echo "❌ pnpm安装失败"
        exit 1
    fi
fi
echo "✅ Node.js和pnpm已安装"

# 创建虚拟环境
echo "🐍 创建Python虚拟环境..."
$PYTHON_CMD -m venv .venv
source .venv/bin/activate

# 分步安装xinference依赖（在虚拟环境中）
# pip cache purge
pip install 'xinference'
pip install "xinference[transformers]"
pip install sentence-transformers
pip install "xinference[mlx]"


# 退出虚拟环境
deactivate

# 定义路径
MCP_BRIDGE_DIR="$DIFY_DIR/mcp-bridge"
DIFY_DATA_DIR="$PROJECT_ROOT/mcp/data/dify_data"

# 创建数据目录
echo "📁 创建数据目录..."
mkdir -p "$DIFY_DATA_DIR"
echo "✅ 数据目录创建成功: $DIFY_DATA_DIR"

# 1. 启动Docker中间件服务
# 导入start.sh中的Docker启动函数
source "$SCRIPT_DIR/start.sh"

# 创建middleware.env文件（如果需要）
cd "$DIFY_DIR/docker"
if [ ! -f "middleware.env" ]; then
    cp middleware.env.example middleware.env
fi
cd "$DIFY_DIR"

# 调用start_docker_services函数启动Docker中间件
 if ! start_docker_daemon; then
    echo "❌ 无法自动启动Docker服务，请手动启动Docker后再运行脚本"
    exit 1
fi
start_docker_services
if [ $? -ne 0 ]; then
    echo "❌ Docker中间件服务启动失败"
    exit 1
fi

# 2. 配置Dify API服务
echo "⚙️ 配置Dify API服务..."
cd "$DIFY_DIR/api"
if [ ! -f ".env" ]; then
    cp .env.example .env
    # 生成SECRET_KEY
    SECRET_KEY=$(openssl rand -base64 42)
    sed_in_place "s/^SECRET_KEY=.*/SECRET_KEY=${SECRET_KEY}/" .env
fi

# 安装API依赖
echo "📦 安装API服务依赖..."
uv sync
if [ $? -ne 0 ]; then
    echo "❌ API依赖安装失败"
    exit 1
fi

# macOS需要安装libmagic
if [ "$(uname)" = "Darwin" ]; then
    if ! brew list libmagic &> /dev/null; then
        echo "📦 安装libmagic..."
        brew install libmagic
    fi
fi

# 数据库迁移
echo "🗄️ 执行数据库迁移..."
uv run flask db upgrade
if [ $? -ne 0 ]; then
    echo "❌ 数据库迁移失败"
    exit 1
fi
echo "✅ API服务配置完成"

# 3. 配置Dify Web服务
echo "🌐 配置Dify Web服务..."
cd "$DIFY_DIR/web"
# 安装前端依赖
echo "📦 安装前端依赖..."
pnpm install --frozen-lockfile
if [ $? -ne 0 ]; then
    echo "❌ 前端依赖安装失败"
    exit 1
fi

# 配置前端环境变量
if [ ! -f ".env.local" ]; then
    cp .env.example .env.local
fi

# 构建前端
echo "🔨 构建前端应用..."
pnpm build
if [ $? -ne 0 ]; then
    echo "⚠️ 前端构建失败，但继续部署"
else
    echo "✅ 前端构建成功"
fi
echo "✅ Web服务配置完成"

# 4. 安装MCP Bridge
echo "🌉 安装MCP Bridge..."
cd "$MCP_BRIDGE_DIR"

# 检查install.sh是否存在
if [ -f "install.sh" ]; then
    echo "📦 调用install.sh安装MCP Bridge..."
    chmod +x install.sh
    bash install.sh
    if [ $? -ne 0 ]; then
        echo "❌ MCP Bridge安装失败"
        exit 1
    fi
    echo "✅ MCP Bridge安装成功"
else
    echo "❌ install.sh文件不存在，请确保MCP Bridge目录结构正确"
    exit 1
fi

# 5. 创建环境配置文件
echo "⚙️ 创建环境配置..."
cat > "$DIFY_DIR/.env" << EOF
# Dify API配置
DIFY_API_URL=http://localhost:5001/v1
DIFY_API_KEY=

# MCP Bridge配置
DIFY_MCP_BRIDGE_PATH=$MCP_BRIDGE_DIR

# 数据存储路径
DIFY_DATA_DIR=$DIFY_DATA_DIR
EOF

# 添加配置规则（如果工具已加载）
if [ "${CONFIG_RULES_UTILS_LOADED}" = "true" ]; then
  # 准备配置内容（使用相对路径）
  CONFIG_CONTENT="{
  \"mcpServers\": {
    \"dify-knowledge\": {
      \"command\": \"${MCP_BRIDGE_DIR}/.venv/bin/python\",
      \"args\": [
        \"-m\", \"src.mcp_server\"
      ],
      \"env\": {
        \"DIFY_API_URL\": \"http://localhost:5001/v1\",
        \"DIFY_API_KEY\": \"dataset-Cum968WkXxtIp8RImIrjTUNA\",
        \"PYTHONPATH\": \"${MCP_BRIDGE_DIR}\"
      },
      \"cwd\": \"${DIFY_DIR}\"
    }
  }
}"

  # 添加配置规则
  add_config_rule \
    "dify-mcp-config" \
    "Dify MCP配置" \
    "将Dify MCP配置添加到Cursor配置文件中，确保JSON格式正确。需要先启动Dify服务并获取API密钥。" \
    "$CONFIG_CONTENT" \
    ".cursor/mcp.json" \
    "15"
  
  echo "✅ Dify MCP配置规则已添加"
fi

echo ""
echo "🎉 Dify MCP工具部署完成"
echo ""
echo "📋 部署信息:"
echo "   项目目录: $DIFY_DIR"
echo "   Dify源码: $DIFY_DIR"
echo "   MCP Bridge: $MCP_BRIDGE_DIR"
echo "   数据目录: $DIFY_DATA_DIR"
echo "   Python版本: $PYTHON_VERSION"
echo ""
echo "🚀 启动服务:"
echo "   1. 启动Dify API: cd $DIFY_DIR/api && uv run flask run --host 0.0.0.0 --port=5001"
echo "   2. 启动Celery Worker: cd $DIFY_DIR/api && uv run celery -A app.celery worker -P gevent -c 1"
echo "   3. 启动Web界面: cd $DIFY_DIR/web && pnpm start"
echo "   4. 配置API密钥并启动MCP Bridge"
echo ""
echo "🔗 访问地址:"
echo "   API服务: http://localhost:5001/v1"
echo "   Web界面: http://localhost:3000"
echo ""
echo "⚙️ 配置任务已记录，请在所有部署完成后查阅配置指南"

# 如果是用户直接调用，生成配置摘要
if [ "$PARENT_CALL" = false ] && [ "${CONFIG_RULES_UTILS_LOADED}" = "true" ]; then
    echo ""
    echo "生成配置规则汇总..."
    generate_config_summary
fi

exit 0 