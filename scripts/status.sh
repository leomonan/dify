#!/bin/bash
# Dify MCP工具状态检查脚本
# 文件名: status.sh
# 描述: 检查Dify AI平台及MCP Bridge服务状态
# 创建日期: 2025年1月29日星期三 12:30:00
# 最后更新日期: 2025年6月23日星期一 18:15:35

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

# 使用简单变量替代关联数组
DIFY_API_STATUS=""
DIFY_WEB_STATUS=""
MCP_BRIDGE_STATUS=""
POSTGRESQL_STATUS=""
REDIS_STATUS=""
WEAVIATE_STATUS=""
ELASTICSEARCH_STATUS=""
CELERY_WORKER_STATUS=""

# 检查服务状态的函数
is_service_running() {
    local service_name="$1"
    local service_var="${service_name}_STATUS"
    service_var=$(echo "$service_var" | tr '-' '_')
    
    # 根据服务名称获取对应的状态变量
    case "$service_var" in
        "Dify_API_STATUS") echo "$DIFY_API_STATUS" ;;
        "Dify_Web_STATUS") echo "$DIFY_WEB_STATUS" ;;
        "MCP_Bridge_STATUS") echo "$MCP_BRIDGE_STATUS" ;;
        "PostgreSQL_STATUS") echo "$POSTGRESQL_STATUS" ;;
        "Redis_STATUS") echo "$REDIS_STATUS" ;;
        "Weaviate_STATUS") echo "$WEAVIATE_STATUS" ;;
        "Elasticsearch_STATUS") echo "$ELASTICSEARCH_STATUS" ;;
        "Celery_Worker_STATUS") echo "$CELERY_WORKER_STATUS" ;;
        *) echo "" ;;
    esac
}

# 设置服务状态的函数
set_service_status() {
    local service_name="$1"
    local status="$2"
    
    # 根据服务名称设置对应的状态变量
    case "$service_name" in
        "Dify-API") DIFY_API_STATUS="$status" ;;
        "Dify-Web") DIFY_WEB_STATUS="$status" ;;
        "MCP-Bridge") MCP_BRIDGE_STATUS="$status" ;;
        "PostgreSQL") POSTGRESQL_STATUS="$status" ;;
        "Redis") REDIS_STATUS="$status" ;;
        "Weaviate") WEAVIATE_STATUS="$status" ;;
        "Elasticsearch") ELASTICSEARCH_STATUS="$status" ;;
        "Celery-Worker") CELERY_WORKER_STATUS="$status" ;;
    esac
}

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
        set_service_status "$service_name" "running"
        return 0
    else
        echo -e " \033[31m❌ 未运行\033[0m"
        FAILED_SERVICES=$((FAILED_SERVICES + 1))
        set_service_status "$service_name" "failed"
        return 1
    fi
}

# 改进的端口状态检查函数
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
    
    # 尝试多种方式检查端口
    if lsof -i :$port >/dev/null 2>&1 || nc -z localhost $port >/dev/null 2>&1 || curl -s http://localhost:$port >/dev/null 2>&1; then
        echo -e " \033[32m✅ 端口 $port 开放\033[0m"
        RUNNING_SERVICES=$((RUNNING_SERVICES + 1))
        set_service_status "$service_name" "running"
        return 0
    else
        echo -e " \033[31m❌ 端口 $port 未开放\033[0m"
        FAILED_SERVICES=$((FAILED_SERVICES + 1))
        set_service_status "$service_name" "failed"
        return 1
    fi
}

# 改进的PID文件状态检查函数
check_pid_status() {
    local service_name="$1"
    local pid_file="$2"
    local description="$3"
    
    # 如果服务已经被标记为运行中，则跳过PID检查
    if [ "$(is_service_running "$service_name")" = "running" ]; then
        echo -e "  $service_name: \033[32m✅ 服务已验证运行中\033[0m"
        return 0
    fi
    
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
            set_service_status "$service_name" "running"
            return 0
        else
            # 即使PID不存在，也尝试检查进程名称
            if ps aux | grep -v "grep" | grep -E "$service_name|${service_name,,}" >/dev/null 2>&1; then
                echo -e " \033[33m⚠️ PID文件与进程不匹配，但服务可能运行中\033[0m"
                RUNNING_SERVICES=$((RUNNING_SERVICES + 1))
                set_service_status "$service_name" "running"
                return 0
            else
                echo -e " \033[33m⚠️ PID文件存在但进程不存在 (PID: $pid)\033[0m"
                FAILED_SERVICES=$((FAILED_SERVICES + 1))
                set_service_status "$service_name" "failed"
                return 1
            fi
        fi
    else
        echo -e " \033[31m❌ PID文件不存在\033[0m"
        FAILED_SERVICES=$((FAILED_SERVICES + 1))
        set_service_status "$service_name" "failed"
        return 1
    fi
}

echo "🔍 开始检查 Dify MCP 服务状态..."
echo ""

# 1. 检查端口状态（先检查端口，因为这是最可靠的服务可用性指标）
echo "🌐 检查端口状态:"
check_port_status "Dify-API" "5001" "Dify API服务"
check_port_status "Dify-Web" "3000" "Dify Web界面"
check_port_status "MCP-Bridge" "8080" "MCP Bridge服务" 
check_port_status "PostgreSQL" "5432" "PostgreSQL数据库"
check_port_status "Redis" "6379" "Redis缓存"
check_port_status "Weaviate" "8080" "Weaviate向量数据库"

# 2. 检查Docker中间件服务
echo ""
echo "📦 检查Docker中间件服务:"

# 改进的Docker服务检测功能
check_docker_service() {
    local service_name="$1"
    local port="$2"
    local container_pattern="$3"
    local description="$4"
    
    # 如果服务已经被标记为运行中，则跳过检查
    if [ "$(is_service_running "$service_name")" = "running" ]; then
        echo -e "  $service_name: \033[32m✅ 服务已验证运行中\033[0m"
        return 0
    fi
    
    TOTAL_SERVICES=$((TOTAL_SERVICES + 1))
    
    echo -n "  $service_name: "
    
    # 首先尝试通过端口检测服务
    if lsof -i :$port >/dev/null 2>&1 || nc -z localhost $port >/dev/null 2>&1; then
        echo -e " \033[32m✅ 运行中\033[0m"
        RUNNING_SERVICES=$((RUNNING_SERVICES + 1))
        set_service_status "$service_name" "running"
        return 0
    fi
    
    # 如果端口检测失败，尝试通过容器名称检测
    if docker ps 2>/dev/null | grep -E "$container_pattern" | grep -v grep >/dev/null 2>&1; then
        echo -e " \033[32m✅ 运行中\033[0m"
        RUNNING_SERVICES=$((RUNNING_SERVICES + 1))
        set_service_status "$service_name" "running"
        return 0
    fi
    
    # 两种方法都失败
    echo -e " \033[31m❌ 未运行\033[0m"
    FAILED_SERVICES=$((FAILED_SERVICES + 1))
    set_service_status "$service_name" "failed"
    return 1
}

# 使用新函数检测各中间件服务
check_docker_service "PostgreSQL" "5432" "postgres|postgresql|dify-postgres" "PostgreSQL数据库"
check_docker_service "Redis" "6379" "redis|dify-redis" "Redis缓存"
check_docker_service "Weaviate" "8080" "weaviate|dify-weaviate" "Weaviate向量数据库"
check_docker_service "Elasticsearch" "9200" "elastic|elasticsearch|dify-elasticsearch" "Elasticsearch搜索引擎"

# 3. 尝试使用HTTP请求验证Web服务和MCP Bridge
echo ""
echo "🌐 验证Web服务可访问性:"
check_web_service() {
    local service_name="$1"
    local url="$2"
    local description="$3"
    
    # 如果服务已经被标记为运行中，则跳过检查
    if [ "$(is_service_running "$service_name")" = "running" ]; then
        echo -e "  $service_name: \033[32m✅ 服务已验证运行中\033[0m"
        return 0
    fi
    
    TOTAL_SERVICES=$((TOTAL_SERVICES + 1))
    
    if [ "$VERBOSE" = true ]; then
        echo -n "🔍 检查 $description..."
    else
        echo -n "  $service_name: "
    fi
    
    # 发送HTTP请求，超时设置为2秒
    if curl -s -m 2 "$url" >/dev/null 2>&1; then
        echo -e " \033[32m✅ 服务可访问\033[0m"
        RUNNING_SERVICES=$((RUNNING_SERVICES + 1))
        set_service_status "$service_name" "running"
        return 0
    else
        # 即使HTTP请求失败，也再次检查端口
        local port=$(echo "$url" | sed -E 's/.*:([0-9]+).*/\1/')
        if lsof -i :$port >/dev/null 2>&1 || nc -z localhost $port >/dev/null 2>&1; then
            echo -e " \033[33m⚠️ 端口开放但HTTP请求失败\033[0m"
            RUNNING_SERVICES=$((RUNNING_SERVICES + 1))
            set_service_status "$service_name" "running"
            return 0
        else
            echo -e " \033[31m❌ 服务不可访问\033[0m"
            FAILED_SERVICES=$((FAILED_SERVICES + 1))
            set_service_status "$service_name" "failed"
            return 1
        fi
    fi
}

check_web_service "Dify-Web" "http://localhost:3000" "Dify Web界面"
check_web_service "MCP-Bridge" "http://localhost:8080/health" "MCP Bridge服务"
check_web_service "Dify-API" "http://localhost:5001/api/status" "Dify API服务"

# 4. 检查PID文件状态 - 现在作为辅助信息
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

# 5. 检查虚拟环境状态
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

# 6. 检查日志文件
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

# 7. 检查数据目录
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

# 8. 显示详细信息（如果启用verbose模式）
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
    
    # PID文件内容
    echo ""
    echo "PID文件内容:"
    for pid_file in "$PIDS_DIR"/*.pid; do
        if [ -f "$pid_file" ]; then
            pid=$(cat "$pid_file")
            echo "  $(basename "$pid_file"): PID=$pid"
            # 尝试查找进程
            ps -p "$pid" >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo "    ✅ 进程存在"
            else
                echo "    ⚠️ 进程不存在，但服务可能通过其他方式运行"
            fi
        fi
    done
fi

# 修正服务统计信息
# 确保不重复计算某些服务
echo ""
echo "📊 状态总结:"
echo "  运行中的服务: $RUNNING_SERVICES"
echo "  未运行的服务: $FAILED_SERVICES"

# 检查核心服务的状态并提供详细报告
core_services=("Dify-API" "Dify-Web" "MCP-Bridge" "PostgreSQL" "Redis" "Weaviate")
core_running=0
core_failed=0

echo ""
echo "🔍 核心服务状态:"
for service in "${core_services[@]}"; do
    if [ "$(is_service_running "$service")" = "running" ]; then
        echo -e "  $service: \033[32m✅ 运行中\033[0m"
        core_running=$((core_running + 1))
    else
        echo -e "  $service: \033[31m❌ 未运行\033[0m"
        core_failed=$((core_failed + 1))
    fi
done

if [ $core_failed -eq 0 ]; then
    echo "  🎉 所有核心服务运行正常!"
    exit_code=0
elif [ $core_running -gt 0 ]; then
    echo "  ⚠️ 部分核心服务运行正常，部分服务存在问题"
    exit_code=1
else
    echo "  ❌ 所有核心服务都未运行"
    exit_code=2
fi

echo ""
echo "💡 提示:"
echo "  - 启动服务: ./scripts/start.sh"
echo "  - 停止服务: ./scripts/stop.sh"
echo "  - 查看日志: ls -la $LOGS_DIR/"
echo "  - 详细状态: $0 --verbose"

exit $exit_code 