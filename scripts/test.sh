#!/bin/bash
# Dify MCP 测试脚本
# 文件名: test.sh
# 描述: 测试Dify本地环境和MCP Bridge连接
# 最后更新日期: 2025年6月23日星期一 10:13:16

# 获取scripts目录的绝对路径
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# 获取dify目录的绝对路径
DIFY_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
# 获取third-party目录的绝对路径
THIRD_PARTY_DIR="$( cd "$DIFY_DIR/.." && pwd )"
# 获取项目根目录的绝对路径
PROJECT_ROOT="$( cd "$THIRD_PARTY_DIR/../.." && pwd )"

# 确保在正确的目录下
cd "$DIFY_DIR"

echo "🧪 测试 Dify MCP 环境..."

# 定义路径
MCP_BRIDGE_DIR="$DIFY_DIR/mcp-bridge"
DIFY_DATA_DIR="$PROJECT_ROOT/mcp/data/dify_data"

# 测试结果数组
PASSED_TESTS=()
FAILED_TESTS=()

# 工具检测函数
test_tool() {
    local tool_name="$1"
    local tool_command="$2"
    local test_description="$3"
    
    echo "🔍 测试${test_description}..."
    if command -v "$tool_command" &> /dev/null; then
        local version=$($tool_command --version 2>&1 | head -n1)
        echo "✅ $tool_name: $version"
        PASSED_TESTS+=("$test_description")
        return 0
    else
        echo "❌ $tool_name 未安装"
        FAILED_TESTS+=("$test_description")
        return 1
    fi
}

# 目录结构测试函数
test_directory() {
    local dir_name="$1"
    local dir_path="$2"
    local test_description="$3"
    
    echo "🔍 测试${test_description}..."
    if [ -d "$dir_path" ]; then
        echo "✅ $dir_name 目录存在: $dir_path"
        PASSED_TESTS+=("$test_description")
        return 0
    else
        echo "❌ $dir_name 目录不存在: $dir_path"
        FAILED_TESTS+=("$test_description")
        return 1
    fi
}

# 配置文件测试函数
test_config_file() {
    local file_name="$1"
    local file_path="$2"
    local test_description="$3"
    
    echo "🔍 测试${test_description}..."
    if [ -f "$file_path" ]; then
        echo "✅ $file_name 配置文件存在"
        PASSED_TESTS+=("$test_description")
        return 0
    else
        echo "❌ $file_name 配置文件不存在: $file_path"
        FAILED_TESTS+=("$test_description")
        return 1
    fi
}

echo "🔧 开始基础环境检测..."

# 1. 系统工具检测
test_tool "Docker" "docker" "Docker环境"
test_tool "Git" "git" "Git工具"
test_tool "Python3" "python3" "Python环境"
test_tool "uv" "uv" "UV包管理器"
test_tool "Node.js" "node" "Node.js环境"
test_tool "PNPM" "pnpm" "PNPM包管理器"

# 2. Docker服务检测
echo ""
echo "🐳 检测Docker服务状态..."
if command -v docker &> /dev/null; then
    if docker info &> /dev/null; then
        echo "✅ Docker服务运行正常"
        PASSED_TESTS+=("Docker服务状态")
    else
        echo "❌ Docker服务未运行"
        FAILED_TESTS+=("Docker服务状态")
    fi
else
    echo "❌ Docker未安装"
    FAILED_TESTS+=("Docker安装状态")
fi

# 3. 目录结构检测
echo ""
echo "📁 检测项目目录结构..."
test_directory "Dify项目" "$DIFY_DIR" "Dify项目目录"
test_directory "MCP Bridge" "$MCP_BRIDGE_DIR" "MCP Bridge目录"
test_directory "数据目录" "$DIFY_DATA_DIR" "数据存储目录"

# 4. 关键配置文件检测
echo ""
echo "📄 检测配置文件..."
if [ -d "$DIFY_DIR" ]; then
    test_config_file "API环境配置" "$DIFY_DIR/api/.env" "API环境配置文件"
    test_config_file "Web环境配置" "$DIFY_DIR/web/.env.local" "Web环境配置文件"
    test_config_file "Docker Compose" "$DIFY_DIR/docker/docker-compose.middleware.yaml" "Docker配置文件"
fi

if [ -d "$MCP_BRIDGE_DIR" ]; then
    test_config_file "MCP配置" "$PROJECT_ROOT/.cursor/mcp.json" "MCP配置文件"
fi

# 5. 虚拟环境检测
echo ""
echo "🐍 检测Python虚拟环境..."
if [ -d "$MCP_BRIDGE_DIR/.venv" ]; then
    echo "✅ MCP Bridge虚拟环境存在"
    PASSED_TESTS+=("MCP Bridge虚拟环境")
else
    echo "❌ MCP Bridge虚拟环境不存在"
    FAILED_TESTS+=("MCP Bridge虚拟环境")
fi

# 6. 依赖包检测
echo ""
echo "📦 检测依赖包安装..."
if [ -d "$DIFY_DIR/web/node_modules" ]; then
    echo "✅ Web前端依赖包已安装"
    PASSED_TESTS+=("Web前端依赖")
else
    echo "❌ Web前端依赖包未安装"
    FAILED_TESTS+=("Web前端依赖")
fi

# 7. 服务连接测试
echo ""
echo "🌐 测试服务连接..."

# 测试Docker中间件服务
if [ -d "$DIFY_DIR/docker" ]; then
    cd "$DIFY_DIR/docker"
    if [ -f "docker-compose.middleware.yaml" ]; then
        running_containers=$(docker-compose -f docker-compose.middleware.yaml ps -q 2>/dev/null)
        if [ -n "$running_containers" ]; then
            echo "✅ Docker中间件服务运行中"
            PASSED_TESTS+=("Docker中间件运行状态")
            
            # 测试PostgreSQL连接
            postgres_container=$(docker-compose -f docker-compose.middleware.yaml ps -q postgres 2>/dev/null)
            if [ -n "$postgres_container" ]; then
                echo "🔍 测试PostgreSQL连接..."
                if docker exec "$postgres_container" pg_isready -U postgres > /dev/null 2>&1; then
                    echo "✅ PostgreSQL连接正常"
                    PASSED_TESTS+=("PostgreSQL连接")
                else
                    echo "❌ PostgreSQL连接失败"
                    FAILED_TESTS+=("PostgreSQL连接")
                fi
            fi
            
            # 测试Redis连接
            redis_container=$(docker-compose -f docker-compose.middleware.yaml ps -q redis 2>/dev/null)
            if [ -n "$redis_container" ]; then
                echo "🔍 测试Redis连接..."
                if docker exec "$redis_container" redis-cli ping 2>/dev/null | grep -q PONG; then
                    echo "✅ Redis连接正常"
                    PASSED_TESTS+=("Redis连接")
                else
                    echo "❌ Redis连接失败"
                    FAILED_TESTS+=("Redis连接")
                fi
            fi
        else
            echo "❌ Docker中间件服务未运行"
            FAILED_TESTS+=("Docker中间件运行状态")
        fi
    fi
    cd "$DIFY_DIR"
fi

# 8. 环境变量检测
echo ""
echo "🔧 检测环境变量配置..."
if [ -f "$MCP_BRIDGE_DIR/.env" ]; then
    source "$MCP_BRIDGE_DIR/.env"
    
    # 检查关键环境变量
    if [ -n "$DIFY_API_KEY" ]; then
        echo "✅ DIFY_API_KEY 已配置"
        PASSED_TESTS+=("DIFY_API_KEY配置")
    else
        echo "⚠️ DIFY_API_KEY 未配置"
        FAILED_TESTS+=("DIFY_API_KEY配置")
    fi
    
    if [ -n "$DIFY_API_URL" ]; then
        echo "✅ DIFY_API_URL 已配置: $DIFY_API_URL"
        PASSED_TESTS+=("DIFY_API_URL配置")
    else
        echo "ℹ️ DIFY_API_URL 使用默认值"
    fi
else
    echo "⚠️ 环境配置文件 .env 不存在"
    FAILED_TESTS+=("环境配置文件")
fi

# 9. 使用test_mcp.py测试API服务和Web界面
echo ""
echo "🧪 使用test_mcp.py测试Dify服务和MCP集成..."
if [ -d "$MCP_BRIDGE_DIR" ]; then
    if [ -f "$MCP_BRIDGE_DIR/test_mcp.py" ]; then
        cd "$MCP_BRIDGE_DIR"
        if [ -d ".venv" ]; then
            # 激活虚拟环境
            source .venv/bin/activate
            
            # 设置环境变量
            export DIFY_API_URL="${DIFY_API_URL:-http://localhost:5001/v1}"
            export DIFY_API_KEY="${DIFY_API_KEY}"
            
            # 执行测试脚本
            echo "🔍 执行test_mcp.py测试脚本..."
            python test_mcp.py
            TEST_RESULT=$?
            
            if [ $TEST_RESULT -eq 0 ]; then
                echo "✅ MCP集成测试通过"
                PASSED_TESTS+=("MCP集成测试")
            else
                echo "❌ MCP集成测试失败"
                FAILED_TESTS+=("MCP集成测试")
            fi
            
            # 退出虚拟环境
            deactivate
        else
            echo "❌ 虚拟环境不存在，无法执行测试脚本"
            FAILED_TESTS+=("虚拟环境测试")
        fi
        cd "$DIFY_DIR"
    else
        echo "❌ 测试脚本不存在: $MCP_BRIDGE_DIR/test_mcp.py"
        FAILED_TESTS+=("测试脚本缺失")
    fi
else
    echo "❌ MCP Bridge目录不存在，无法执行测试"
    FAILED_TESTS+=("MCP Bridge测试")
fi

# 10. MCP Bridge依赖检测
echo ""
echo "🌉 测试MCP Bridge依赖..."
if [ -d "$MCP_BRIDGE_DIR" ]; then
    cd "$MCP_BRIDGE_DIR"
    if [ -d ".venv" ]; then
        source .venv/bin/activate
        
        # 检查关键依赖包
        if python -c "import mcp" 2>/dev/null; then
            echo "✅ MCP包可用"
            PASSED_TESTS+=("MCP包安装")
        else
            echo "❌ MCP包不可用"
            FAILED_TESTS+=("MCP包安装")
        fi
        
        if python -c "import requests" 2>/dev/null; then
            echo "✅ requests包可用"
            PASSED_TESTS+=("requests包安装")
        else
            echo "❌ requests包不可用"
            FAILED_TESTS+=("requests包安装")
        fi
        
        deactivate
    fi
    cd "$DIFY_DIR"
fi

# 测试结果汇总
echo ""
echo "📊 测试结果汇总..."
echo ""

if [ ${#PASSED_TESTS[@]} -gt 0 ]; then
    echo "✅ 通过的测试 (${#PASSED_TESTS[@]}项):"
    for test in "${PASSED_TESTS[@]}"; do
        echo "   - $test"
    done
    echo ""
fi

if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
    echo "❌ 失败的测试 (${#FAILED_TESTS[@]}项):"
    for test in "${FAILED_TESTS[@]}"; do
        echo "   - $test"
    done
    echo ""
fi

# 总体评估
TOTAL_TESTS=$((${#PASSED_TESTS[@]} + ${#FAILED_TESTS[@]}))
PASS_RATE=$((${#PASSED_TESTS[@]} * 100 / TOTAL_TESTS))

echo "📈 测试统计:"
echo "   总测试项: $TOTAL_TESTS"
echo "   通过: ${#PASSED_TESTS[@]}"
echo "   失败: ${#FAILED_TESTS[@]}"
echo "   通过率: $PASS_RATE%"
echo ""

# 给出建议
if [ ${#FAILED_TESTS[@]} -eq 0 ]; then
    echo "🎉 所有测试通过! Dify MCP环境配置完整。"
    echo ""
    echo "🚀 下一步操作:"
    echo "   1. 启动所有服务: ./scripts/start.sh"
    echo "   2. 访问Web界面: http://localhost:3000"
    echo "   3. 在Cursor中配置MCP连接"
else
    echo "⚠️ 环境存在问题，建议按以下步骤修复："
    echo ""
    
    # 根据失败的测试给出具体建议
    for test in "${FAILED_TESTS[@]}"; do
        case "$test" in
            *"Docker"*)
                echo "🔧 Docker问题:"
                echo "   - 安装Docker Desktop"
                echo "   - 启动Docker服务"
                ;;
            *"目录"*)
                echo "🔧 目录问题:"
                echo "   - 运行部署脚本: ./scripts/deploy.sh"
                ;;
            *"配置文件"*)
                echo "🔧 配置文件问题:"
                echo "   - 检查部署是否完整"
                echo "   - 重新运行部署脚本"
                ;;
            *"虚拟环境"*)
                echo "🔧 虚拟环境问题:"
                echo "   - 重新创建虚拟环境"
                echo "   - 安装依赖包"
                ;;
            *"MCP集成测试"*)
                echo "🔧 MCP集成测试问题:"
                echo "   - 检查test_mcp.py是否有错误"
                echo "   - 确保Dify服务已启动"
                echo "   - 检查API密钥是否有效"
                ;;
            *"测试脚本"*)
                echo "🔧 测试脚本问题:"
                echo "   - 检查test_mcp.py是否存在"
                echo "   - 确保test_mcp.py有正确的权限"
                ;;
            *"服务"*|*"连接"*)
                echo "🔧 服务连接问题:"
                echo "   - 确保相关服务已启动"
                echo "   - 检查网络连接"
                echo "   - 验证服务端口是否正确"
                ;;
            *"环境变量"*|*"API_KEY"*)
                echo "🔧 环境变量问题:"
                echo "   - 在.env文件中设置DIFY_API_KEY"
                echo "   - 确保在Dify管理界面已生成API密钥"
                ;;
            *)
                echo "🔧 一般性问题:"
                echo "   - 查看具体失败测试项"
                echo "   - 检查相关组件和配置"
                ;;
        esac
    done
    
    echo ""
    echo "💡 通用解决方案:"
    echo "   1. 重新部署: ./scripts/clean.sh && ./scripts/deploy.sh"
    echo "   2. 检查日志文件查看详细错误"
    echo "   3. 确保所需端口未被占用"
fi

echo ""
echo "📖 更多信息请参考: README.md"

# 根据测试结果设置退出码
if [ ${#FAILED_TESTS[@]} -eq 0 ]; then
    exit 0
else
    exit 1
fi                