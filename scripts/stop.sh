#!/bin/bash
# Dify MCP 停止脚本
# 文件名: stop.sh
# 描述: 停止Dify本地环境和MCP Bridge服务
# 最后更新日期: 2025年6月23日星期一 10:13:16

# 获取scripts目录的绝对路径
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# 获取dify目录的绝对路径
DIFY_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
# 获取third-party目录的绝对路径
THIRD_PARTY_DIR="$( cd "$DIFY_DIR/.." && pwd )"
# 获取项目根目录的绝对路径
PROJECT_ROOT="$( cd "$THIRD_PARTY_DIR/../.." && pwd )"

# 导入通用工具函数
source "$PROJECT_ROOT/scripts/lib/common_utils.sh"

# 确保在正确的目录下
cd "$DIFY_DIR"

# 显示使用说明
show_usage() {
    echo "用法: $0 [OPTIONS]"
    echo ""
    echo "选项:"
    echo "  -f, --force           强制停止所有相关进程"
    echo "  -v, --verbose         显示详细信息"
    echo "  -h, --help           显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0                    # 停止所有Dify服务"
    echo "  $0 -f                 # 强制停止所有服务"
    echo "  $0 -v                 # 详细显示停止过程"
}

# 默认参数
FORCE=false
VERBOSE=false

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
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "未知选项: $1"
            show_usage
            exit 1
            ;;
    esac
done

echo "🛑 正在停止 Dify MCP 服务..."

# 定义路径

# 停止服务函数
stop_service_by_pid() {
    local service_name="$1"
    local pid_file="$2"
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if [ -n "$pid" ] && ps -p $pid > /dev/null 2>&1; then
            echo "🔄 正在停止${service_name} (PID: $pid)..."
            if [ "$FORCE" = true ]; then
                kill -9 $pid 2>/dev/null
            else
                kill $pid 2>/dev/null
            fi
            
            # 等待进程停止
            local count=0
            while [ $count -lt 10 ] && ps -p $pid > /dev/null 2>&1; do
                sleep 1
                count=$((count + 1))
            done
            
            if ps -p $pid > /dev/null 2>&1; then
                echo "⚠️ ${service_name}进程未正常停止，强制终止..."
                kill -9 $pid 2>/dev/null
            fi
            
            echo "✅ ${service_name}已停止"
        else
            echo "ℹ️ ${service_name}未在运行"
        fi
        rm -f "$pid_file"
    fi
}

stop_service_by_pattern() {
    local service_name="$1"
    local pattern="$2"
    
    local pids=$(pgrep -f "$pattern" || true)
    if [ -n "$pids" ]; then
        echo "🔄 正在停止${service_name}进程: $pids"
        
        for pid in $pids; do
            if [ "$FORCE" = true ]; then
                kill -9 $pid 2>/dev/null
            else
                kill $pid 2>/dev/null
            fi
        done
        
        # 等待进程停止
        sleep 2
        
        # 检查是否还在运行
        local remaining=$(pgrep -f "$pattern" || true)
        if [ -n "$remaining" ]; then
            echo "⚠️ ${service_name}进程未正常停止，强制终止..."
            for pid in $remaining; do
                kill -9 $pid 2>/dev/null
            done
        fi
        
        echo "✅ ${service_name}已停止"
    else
        echo "ℹ️ ${service_name}未在运行"
    fi
}

# 2. 停止Web界面
echo "🌐 停止Dify Web界面..."
# stop_service_by_pid "Web界面" "$DIFY_DIR/logs/web.pid"
stop_service_by_pattern "Web界面" "next-server"


# 3. 停止Celery Worker
echo "🔧 停止Celery Worker..."
# stop_service_by_pid "Celery Worker" "$DIFY_DIR/logs/celery.pid"
stop_service_by_pattern "Celery Worker" "celery.*worker"

# 4. 停止API服务
echo "🔧 停止Dify API服务..."
# stop_service_by_pid "API服务" "$DIFY_DIR/logs/api.pid"
stop_service_by_pattern "API服务" "flask.*run.*5001"


# 5. 停止Docker中间件服务
echo "🐳 停止Docker中间件服务..."
if [ -d "$DIFY_DIR/docker" ]; then
    cd "$DIFY_DIR/docker"
    if [ -f "docker-compose.middleware.yaml" ]; then
        echo "🛑 停止Docker Compose服务..."
        docker-compose -f docker-compose.middleware.yaml down
        if [ $? -eq 0 ]; then
            echo "✅ Docker中间件服务已停止"
        else
            echo "⚠️ Docker服务停止时出现问题"
        fi
    else
        echo "ℹ️ Docker Compose配置文件不存在"
    fi
    cd "$DIFY_DIR"
else
    echo "ℹ️ Docker配置目录不存在"
fi

# 6. 清理其他相关进程（如果强制模式）
if [ "$FORCE" = true ]; then
    echo "💀 强制清理所有相关进程..."
    
    # 清理可能遗留的Python进程
    python_pids=$(pgrep -f "python.*dify\|python.*mcp" || true)
    if [ -n "$python_pids" ]; then
        echo "🔄 清理Python相关进程: $python_pids"
        for pid in $python_pids; do
            kill -9 $pid 2>/dev/null
        done
    fi
    
    # 清理可能遗留的Node.js进程
    node_pids=$(pgrep -f "node.*next\|pnpm.*start" || true)
    if [ -n "$node_pids" ]; then
        echo "🔄 清理Node.js相关进程: $node_pids"
        for pid in $node_pids; do
            kill -9 $pid 2>/dev/null
        done
    fi
    
    echo "✅ 强制清理完成"
fi

# 7. 清理PID文件
echo "🗂️ 清理PID文件..."
rm -f "$DIFY_DIR/logs/"*.pid
echo "✅ PID文件清理完成"

# 验证停止结果
echo "🔍 验证停止结果..."

STOPPED_SERVICES=()
REMAINING_SERVICES=()

if ! pgrep -f "next-server" > /dev/null; then
    STOPPED_SERVICES+=("Web界面")
else
    REMAINING_SERVICES+=("Web界面")
fi

if ! pgrep -f "celery.*worker" > /dev/null; then
    STOPPED_SERVICES+=("Celery Worker")
else
    REMAINING_SERVICES+=("Celery Worker")
fi

if ! pgrep -f "flask.*run.*5001" > /dev/null; then
    STOPPED_SERVICES+=("API服务")
else
    REMAINING_SERVICES+=("API服务")
fi

# 检查Docker服务状态
if [ -d "$DIFY_DIR/docker" ]; then
    cd "$DIFY_DIR/docker"
    if [ -f "docker-compose.middleware.yaml" ]; then
        running_containers=$(docker-compose -f docker-compose.middleware.yaml ps -q)
        if [ -z "$running_containers" ]; then
            STOPPED_SERVICES+=("Docker中间件")
        else
            REMAINING_SERVICES+=("Docker中间件")
        fi
    fi
    cd "$DIFY_DIR"
fi

# 显示停止结果
echo ""
if [ ${#STOPPED_SERVICES[@]} -gt 0 ]; then
    echo "✅ 已停止的服务:"
    for service in "${STOPPED_SERVICES[@]}"; do
        echo "   - $service"
    done
fi

if [ ${#REMAINING_SERVICES[@]} -gt 0 ]; then
    echo "⚠️ 仍在运行的服务:"
    for service in "${REMAINING_SERVICES[@]}"; do
        echo "   - $service"
    done
    echo ""
    echo "💡 提示: 使用 -f 选项进行强制停止"
fi

echo ""
echo "🎉 Dify MCP 停止完成!"
echo ""
echo "📋 停止说明:"
echo "   - 已停止所有相关进程"
echo "   - 已停止Docker中间件服务"
echo "   - 已清理PID文件"
echo ""
echo "🚀 重新启动:"
echo "   执行: ./scripts/start.sh"
echo ""
echo "📖 更多信息请参考: README.md"

# 根据结果设置退出码
if [ ${#REMAINING_SERVICES[@]} -gt 0 ]; then
    exit 1
else
    exit 0
fi 