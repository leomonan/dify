#!/bin/bash
# Dify MCP工具状态检查脚本
# 文件名: status.sh
# 描述: 检查Dify AI平台及MCP Bridge服务状态
# 创建日期: 2025年1月29日星期三 12:30:00
# 最后更新日期: 2025年1月29日星期三 12:30:00

# 获取scripts目录的绝对路径
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# 获取dify目录的绝对路径
DIFY_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
# 获取third-party目录的绝对路径
THIRD_PARTY_DIR="$( cd "$DIFY_DIR/.." && pwd )"
# 获取项目根目录的绝对路径
PROJECT_ROOT="$( cd "$THIRD_PARTY_DIR/../.." && pwd )"

# 默认参数
VERBOSE=false
PARENT_CALL=false
SHOW_HELP=false

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --parent-call)
            PARENT_CALL=true
            shift
            ;;
        --help|-h)
            SHOW_HELP=true
            shift
            ;;
        *)
            echo "未知选项: $1"
            echo "使用 --help 查看帮助信息"
            exit 1
            ;;
    esac
done

# 显示帮助信息
if [ "$SHOW_HELP" = true ]; then
    echo "Dify MCP 状态检查脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -v, --verbose      显示详细信息"
    echo "  --parent-call      标识此脚本被父脚本调用"
    echo "  --help, -h         显示此帮助信息"
    echo ""
    exit 0
fi

# 导入统一工具库
source "$PROJECT_ROOT/scripts/lib/common_utils.sh"

# 验证工具加载成功
check_utils_loaded "状态检查" || exit 1

# 显示项目信息
if [ "$PARENT_CALL" = false ]; then
    show_deploy_subproject_config "$DIFY_DIR" "Dify MCP状态检查"
fi

# 确保在正确的目录下
cd "$DIFY_DIR"

# 定义路径
DIFY_API_DIR="$DIFY_DIR/api"
DIFY_WEB_DIR="$DIFY_DIR/web"
MCP_BRIDGE_DIR="$DIFY_DIR/mcp-bridge"
PIDS_DIR="$DIFY_DIR/logs"
LOGS_DIR="$DIFY_DIR/logs"

# 状态统计
TOTAL_SERVICES=0
RUNNING_SERVICES=0
FAILED_SERVICES=0

# 检查单个服务状态
check_service_status() {
    local service_name="$1"
    local check_command="$2"
    local description="$3"
    
    TOTAL_SERVICES=$((TOTAL_SERVICES + 1))
    
    if [ "$VERBOSE" = true ]; then
        echo -n "🔍 检查 $description..."
    else
        echo -n "  $service_name: "
    fi
    
    if eval "$check_command" >/dev/null 2>&1; then
        echo -e " \033[32m✅ 运行中\033[0m"
        RUNNING_SERVICES=$((RUNNING_SERVICES + 1))
        return 0
    else
        echo -e " \033[31m❌ 未运行\033[0m"
        FAILED_SERVICES=$((FAILED_SERVICES + 1))
        return 1
    fi
}

# 检查端口状态
check_port_status() {
    local service_name="$1"
    local port="$2"
    local description="$3"
    
    TOTAL_SERVICES=$((TOTAL_SERVICES + 1))
    
    if [ "$VERBOSE" = true ]; then
        echo -n "🔍 检查 $description (端口 $port)..."
    else
        echo -n "  $service_name: "
    fi
    
    if lsof -i :$port >/dev/null 2>&1; then
        echo -e " \033[32m✅ 端口 $port 开放\033[0m"
        RUNNING_SERVICES=$((RUNNING_SERVICES + 1))
        return 0
    else
        echo -e " \033[31m❌ 端口 $port 未开放\033[0m"
        FAILED_SERVICES=$((FAILED_SERVICES + 1))
        return 1
    fi
}

# 检查PID文件状态
check_pid_status() {
    local service_name="$1"
    local pid_file="$2"
    local description="$3"
    
    TOTAL_SERVICES=$((TOTAL_SERVICES + 1))
    
    if [ "$VERBOSE" = true ]; then
        echo -n "🔍 检查 $description PID..."
    else
        echo -n "  $service_name: "
    fi
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e " \033[32m✅ 运行中 (PID: $pid)\033[0m"
            RUNNING_SERVICES=$((RUNNING_SERVICES + 1))
            return 0
        else
            echo -e " \033[33m⚠️ PID文件存在但进程不存在 (PID: $pid)\033[0m"
            FAILED_SERVICES=$((FAILED_SERVICES + 1))
            return 1
        fi
    else
        echo -e " \033[31m❌ PID文件不存在\033[0m"
        FAILED_SERVICES=$((FAILED_SERVICES + 1))
        return 1
    fi
}

echo "🔍 开始检查 Dify MCP 服务状态..."
echo ""

# 1. 检查Docker中间件服务
echo "📦 检查Docker中间件服务:"

# 改进的Docker服务检测功能
check_docker_service() {
    local service_name="$1"
    local port="$2"
    local container_pattern="$3"
    local description="$4"
    
    TOTAL_SERVICES=$((TOTAL_SERVICES + 1))
    
    echo -n "  $service_name: "
    
    # 首先尝试通过端口检测服务
    if lsof -i :$port >/dev/null 2>&1 || nc -z localhost $port >/dev/null 2>&1; then
        echo -e " \033[32m✅ 运行中\033[0m"
        RUNNING_SERVICES=$((RUNNING_SERVICES + 1))
        return 0
    fi
    
    # 如果端口检测失败，尝试通过容器名称检测
    if docker ps 2>/dev/null | grep -E "$container_pattern" | grep -v grep >/dev/null 2>&1; then
        echo -e " \033[32m✅ 运行中\033[0m"
        RUNNING_SERVICES=$((RUNNING_SERVICES + 1))
        return 0
    fi
    
    # 两种方法都失败
    echo -e " \033[31m❌ 未运行\033[0m"
    FAILED_SERVICES=$((FAILED_SERVICES + 1))
    return 1
}

# 使用新函数检测各中间件服务
check_docker_service "PostgreSQL" "5432" "postgres|postgresql|dify-postgres" "PostgreSQL数据库"
check_docker_service "Redis" "6379" "redis|dify-redis" "Redis缓存"
check_docker_service "Weaviate" "8080" "weaviate|dify-weaviate" "Weaviate向量数据库"
check_docker_service "Elasticsearch" "9200" "elastic|elasticsearch|dify-elasticsearch" "Elasticsearch搜索引擎"

# 2. 检查端口状态
echo ""
echo "🌐 检查端口状态:"
check_port_status "Dify-API" "5001" "Dify API服务"
check_port_status "Dify-Web" "3000" "Dify Web界面"
check_port_status "MCP-Bridge" "8080" "MCP Bridge服务"
check_port_status "PostgreSQL" "5432" "PostgreSQL数据库"
check_port_status "Redis" "6379" "Redis缓存"
check_port_status "Weaviate" "8080" "Weaviate向量数据库"

# 3. 检查PID文件状态
echo ""
echo "📄 检查进程PID状态:"
if [ -d "$PIDS_DIR" ]; then
    check_pid_status "Dify-API" "$PIDS_DIR/api.pid" "Dify API服务"
    check_pid_status "Dify-Web" "$PIDS_DIR/web.pid" "Dify Web服务"
    check_pid_status "Celery-Worker" "$PIDS_DIR/celery.pid" "Celery工作进程"
    check_pid_status "MCP-Bridge" "$PIDS_DIR/mcp.pid" "MCP Bridge服务"
else
    echo "  ⚠️ PID目录不存在: $PIDS_DIR"
fi

# 4. 检查虚拟环境状态
echo ""
echo "🐍 检查Python虚拟环境:"
TOTAL_SERVICES=$((TOTAL_SERVICES + 3))

# Dify API 虚拟环境
if [ -d "$DIFY_API_DIR/.venv" ] && [ -f "$DIFY_API_DIR/.venv/bin/python" ]; then
    echo -e "  Dify-API: \033[32m✅ 虚拟环境正常\033[0m"
    RUNNING_SERVICES=$((RUNNING_SERVICES + 1))
else
    echo -e "  Dify-API: \033[31m❌ 虚拟环境缺失\033[0m"
    FAILED_SERVICES=$((FAILED_SERVICES + 1))
fi

# Dify Web Node环境
if [ -d "$DIFY_WEB_DIR/node_modules" ]; then
    echo -e "  Dify-Web: \033[32m✅ Node环境正常\033[0m"
    RUNNING_SERVICES=$((RUNNING_SERVICES + 1))
else
    echo -e "  Dify-Web: \033[31m❌ Node环境缺失\033[0m"
    FAILED_SERVICES=$((FAILED_SERVICES + 1))
fi

# MCP Bridge 虚拟环境
if [ -d "$MCP_BRIDGE_DIR/.venv" ] && [ -f "$MCP_BRIDGE_DIR/.venv/bin/python" ]; then
    echo -e "  MCP-Bridge: \033[32m✅ 虚拟环境正常\033[0m"
    RUNNING_SERVICES=$((RUNNING_SERVICES + 1))
else
    echo -e "  MCP-Bridge: \033[31m❌ 虚拟环境缺失\033[0m"
    FAILED_SERVICES=$((FAILED_SERVICES + 1))
fi

# 5. 检查日志文件
echo ""
echo "📝 检查日志文件:"
if [ -d "$LOGS_DIR" ]; then
    log_files=("api.log" "web.log" "celery.log" "mcp.log")
    for log_file in "${log_files[@]}"; do
        if [ -f "$LOGS_DIR/$log_file" ]; then
            log_size=$(du -h "$LOGS_DIR/$log_file" | cut -f1)
            echo "  $log_file: ✅ 存在 ($log_size)"
        else
            echo "  $log_file: ⚠️ 不存在"
        fi
    done
else
    echo "  ⚠️ 日志目录不存在: $LOGS_DIR"
fi

# 6. 检查数据目录
echo ""
echo "💾 检查数据目录:"
DATA_DIRS=(
    "$PROJECT_ROOT/mcp/data/dify_data"
    "$DIFY_DIR/api/storage"
    "$DIFY_DIR/docker/volumes"
)

for data_dir in "${DATA_DIRS[@]}"; do
    if [ -d "$data_dir" ]; then
        dir_size=$(du -sh "$data_dir" 2>/dev/null | cut -f1 || echo "N/A")
        echo "  $(basename "$data_dir"): ✅ 存在 ($dir_size)"
    else
        echo "  $(basename "$data_dir"): ⚠️ 不存在"
    fi
done

# 7. 显示详细信息（如果启用verbose模式）
if [ "$VERBOSE" = true ]; then
    echo ""
    echo "🔍 详细信息:"
    
    # Docker容器详细状态
    echo ""
    echo "Docker容器状态:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep dify || echo "  没有运行的Dify容器"
    
    # 进程详细信息
    echo ""
    echo "相关进程:"
    ps aux | grep -E "(dify|celery|mcp-bridge)" | grep -v grep || echo "  没有找到相关进程"
    
    # 网络连接
    echo ""
    echo "网络连接:"
    netstat -tlnp 2>/dev/null | grep -E "(5001|3000|8080|5432|6379|8080)" || echo "  没有找到相关端口监听"
fi

# 总结状态
echo ""
echo "📊 状态总结:"
echo "  总服务数: $TOTAL_SERVICES"
echo "  运行中: $RUNNING_SERVICES"
echo "  未运行: $FAILED_SERVICES"

if [ $FAILED_SERVICES -eq 0 ]; then
    echo "  🎉 所有服务运行正常!"
    exit_code=0
elif [ $RUNNING_SERVICES -gt 0 ]; then
    echo "  ⚠️ 部分服务运行正常，部分服务存在问题"
    exit_code=1
else
    echo "  ❌ 所有服务都未运行"
    exit_code=2
fi

echo ""
echo "💡 提示:"
echo "  - 启动服务: ./scripts/start.sh"
echo "  - 停止服务: ./scripts/stop.sh"
echo "  - 查看日志: ls -la $LOGS_DIR/"
echo "  - 详细状态: $0 --verbose"

exit $exit_code 