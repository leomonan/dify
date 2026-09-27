#!/bin/bash
# Dify MCP工具清理脚本
# 文件名: clean.sh
# 描述: 清理Dify本地环境和MCP Bridge部署文件
# 最后更新日期: 2025年6月23日星期一 11:09:36

# 获取scripts目录的绝对路径
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# 获取dify目录的绝对路径
DIFY_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
# 获取third-party目录的绝对路径
THIRD_PARTY_DIR="$( cd "$DIFY_DIR/.." && pwd )"
# 获取项目根目录的绝对路径
PROJECT_ROOT="$( cd "$THIRD_PARTY_DIR/../.." && pwd )"

# 导入统一工具库
source "$PROJECT_ROOT/scripts/lib/common_utils.sh"

# 验证工具加载成功
check_utils_loaded "Dify清理" || exit 1

# 初始化环境
init_clean_env

# 显示清理信息
show_clean_subproject_config "$DIFY_DIR" "Dify MCP工具"

# 确保在正确的目录下
cd "$DIFY_DIR"

# 询问用户是否确认清理
if ! confirm_operation "清理Dify MCP部署环境（包括Docker服务、源码、依赖、数据等）"; then
    echo "✅ 已取消清理操作"
    exit 0
fi

echo "🧹 开始清理 Dify MCP..."

# 定义路径
MCP_BRIDGE_DIR="$DIFY_DIR/mcp-bridge"
DIFY_DATA_DIR="$PROJECT_ROOT/mcp/data/dify_data"

# 1. 先使用stop.sh脚本停止所有服务
echo "🔄 停止所有运行中的Dify服务..."
if [ -f "$SCRIPT_DIR/stop.sh" ]; then
    # 调用stop.sh脚本停止所有服务，添加--force参数以确保所有服务被停止
    bash "$SCRIPT_DIR/stop.sh" --force
    echo "✅ 服务停止完成"
else
    echo "❌ 停止脚本不存在: $SCRIPT_DIR/stop.sh"
    exit 1
fi

# 2. 清理Dify源码环境
if [ -d "$DIFY_DIR" ]; then
    echo "ℹ️ 保留Dify源码目录，仅清理环境"
    
    # 清理API环境
    if [ -d "$DIFY_DIR/api" ]; then
        echo "🐍 清理API Python环境..."
        cd "$DIFY_DIR/api"
        rm -rf .venv __pycache__ *.pyc .pytest_cache .coverage
        find . -name "*.pyc" -delete 2>/dev/null || true
        find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
        echo "✅ API环境清理完成"
    fi
    
    # 清理Web环境
    if [ -d "$DIFY_DIR/web" ]; then
        echo "🌐 清理Web前端环境..."
        cd "$DIFY_DIR/web"
        rm -rf node_modules .next out dist build
        rm -f package-lock.json yarn.lock
        echo "✅ Web环境清理完成"
    fi
    
    cd "$DIFY_DIR"
    echo "✅ Dify源码环境清理完成"
else
    echo "ℹ️ Dify源码目录不存在"
fi

# 3. 清理MCP Bridge环境
if [ -d "$MCP_BRIDGE_DIR" ]; then
    echo "ℹ️ 保留MCP Bridge目录，仅清理环境"
    echo "🐍 清理MCP Bridge Python环境..."
    cd "$MCP_BRIDGE_DIR"
    rm -rf .venv __pycache__ *.pyc .pytest_cache .coverage
    rm -rf build dist *.egg-info
    find . -name "*.pyc" -delete 2>/dev/null || true
    find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
    cd "$DIFY_DIR"
    echo "✅ MCP Bridge环境清理完成"
else
    echo "ℹ️ MCP Bridge目录不存在"
fi

# 4. 清理数据目录
if [ -d "$DIFY_DATA_DIR" ]; then
    echo "⚠️ 数据目录清理需要二次确认"
    echo "数据目录: $DIFY_DATA_DIR"
    echo "这将永久删除所有Dify存储的数据，包括："
    echo "  - 知识库数据"
    echo "  - 对话历史"
    echo "  - 用户上传的文件"
    echo "  - 数据库内容"
    echo ""
    echo "如果确认删除，请输入: 我确认删除数据目录并知道后果"
    read -p "请输入确认文本: " confirmation
    
    if [ "$confirmation" = "我确认删除数据目录并知道后果" ]; then
        echo "🗑️ 删除数据目录..."
        rm -rf "$DIFY_DATA_DIR"
        echo "✅ 数据目录清理完成"
    else
        echo "ℹ️ 未输入正确确认文本，保留数据目录"
    fi
else
    echo "ℹ️ 数据目录不存在"
fi

# 5. 清理配置文件
echo "🗂️ 清理配置文件..."
if [ -f "$DIFY_DIR/.env" ]; then
    if confirm_operation "删除环境配置文件(.env)"; then
        echo "🗑️ 删除.env文件"
        rm -f "$DIFY_DIR/.env"
    else
        echo "ℹ️ 保留.env文件"
    fi
fi

# 6. 清理日志文件
echo "📋 清理日志文件..."
find "$DIFY_DIR" -name "*.log" -type f -delete 2>/dev/null || true
echo "✅ 日志文件清理完成"

# 7. 清理临时文件
echo "🗂️ 清理临时文件..."
find "$DIFY_DIR" -name "*.tmp" -type f -delete 2>/dev/null || true
find "$DIFY_DIR" -name "*.temp" -type f -delete 2>/dev/null || true
find "$DIFY_DIR" -name ".DS_Store" -type f -delete 2>/dev/null || true
echo "✅ 临时文件清理完成"

# 8. 清理Docker镜像（可选）- 修改为不退出的逻辑
echo "🐳 是否清理Docker镜像?"
read -p "清理Dify相关的Docker镜像（这将删除拉取的中间件镜像）[y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🐳 清理Docker镜像..."
    
    # 清理Dify相关镜像
    docker images | grep -E "(postgres|redis|weaviate|milvus|nginx)" | awk '{print $3}' | xargs -r docker rmi -f 2>/dev/null || true
    
    # 清理悬空镜像
    docker image prune -f 2>/dev/null || true
    
    echo "✅ Docker镜像清理完成"
else
    echo "ℹ️ 保留Docker镜像"
fi

# 验证清理结果
echo "🔍 验证清理结果..."

CLEANED_ITEMS=()
REMAINING_ITEMS=()

# 检查各项清理结果
if [ -d "$DIFY_DIR" ]; then
    CLEANED_ITEMS+=("Dify源码环境")
    REMAINING_ITEMS+=("Dify源码目录")
fi

if [ -d "$MCP_BRIDGE_DIR" ]; then
    CLEANED_ITEMS+=("MCP Bridge环境")
    REMAINING_ITEMS+=("MCP Bridge目录")
fi

if [ ! -d "$DIFY_DATA_DIR" ]; then
    CLEANED_ITEMS+=("数据目录")
else
    REMAINING_ITEMS+=("数据目录")
fi

if [ ! -f "$DIFY_DIR/.env" ]; then
    CLEANED_ITEMS+=("环境配置")
else
    REMAINING_ITEMS+=("环境配置")
fi

# 检查Docker服务状态
DOCKER_CONTAINERS=$(docker ps -q -f "name=postgres\|redis\|weaviate\|milvus" 2>/dev/null || true)
if [ -z "$DOCKER_CONTAINERS" ]; then
    CLEANED_ITEMS+=("Docker服务")
else
    REMAINING_ITEMS+=("Docker服务")
fi

# 显示清理结果
echo ""
if [ ${#CLEANED_ITEMS[@]} -gt 0 ]; then
    echo "✅ 已清理的项目:"
    for item in "${CLEANED_ITEMS[@]}"; do
        echo "   - $item"
    done
fi

if [ ${#REMAINING_ITEMS[@]} -gt 0 ]; then
    echo "ℹ️ 保留的项目:"
    for item in "${REMAINING_ITEMS[@]}"; do
        echo "   - $item"
    done
fi

echo ""
echo "🎉 Dify MCP 清理完成!"
echo ""
echo "📋 清理说明:"
echo "   - 已停止所有相关进程"
echo "   - 已清理构建和缓存文件"
echo "   - 已停止Docker中间件服务"
echo "   - 源码和数据目录根据用户选择处理"
echo ""
echo "🔄 重新部署:"
echo "   执行: ./scripts/deploy.sh"
echo ""
echo "💡 提示:"
echo "   - 如需完全重置，建议同时清理Docker镜像"
echo "   - 重新部署前确保Docker服务正常运行"
echo ""
echo "📖 更多信息请参考: README.md"

exit 0 