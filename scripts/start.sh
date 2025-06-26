#!/bin/bash
# Dify MCP 启动脚本
# 文件名: start.sh
# 描述: 启动Dify本地环境和MCP Bridge服务
# 最后更新日期: 2025年6月24日星期一 15:30:45

# 检测脚本是否被直接执行还是被导入
# 如果被导入，BASH_SOURCE和$0不同
# https://stackoverflow.com/questions/2683279/how-to-detect-if-a-script-is-being-sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  # 脚本被导入，只定义函数，不执行主逻辑
  SCRIPT_SOURCED=true
else
  # 脚本被直接执行
  SCRIPT_SOURCED=false
fi

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

# 显示使用说明
show_usage() {
    echo "用法: $0 [OPTIONS]"
    echo ""
    echo "选项:"
    echo "  -a, --api-only        只启动Dify API服务"
    echo "  -w, --web-only        只启动Dify Web界面"
    echo "  -m, --mcp-only        只启动MCP Bridge"
    echo "  -d, --docker-only     只启动Docker中间件"
    echo "  -b, --background      后台运行"
    echo "  -f, --force           强制启动（跳过检查）"
    echo "  -h, --help           显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0                    # 启动所有服务（前台）"
    echo "  $0 -b                 # 启动所有服务（后台）"
    echo "  $0 -a                 # 只启动API服务"
    echo "  $0 -w -b              # 后台启动Web界面"
    echo "  $0 -d                 # 只启动Docker中间件"
}

# 自动启动Docker服务
start_docker_daemon() {
    echo "🔄 尝试自动启动Docker服务..."
    
    # 检测操作系统类型
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        echo "📱 检测到macOS系统"
        if command -v open &> /dev/null; then
            echo "🚀 启动Docker Desktop..."
            open -a Docker
            
            # 等待Docker启动
            echo "⏳ 等待Docker服务启动，最多等待60秒..."
            for i in {1..12}; do
                sleep 5
                if docker info &> /dev/null; then
                    echo "✅ Docker服务已成功启动"
                    return 0
                fi
                echo "⏳ 等待Docker启动中... ($((i*5))秒)"
            done
        else
            echo "❌ 无法启动Docker Desktop，请手动启动"
            return 1
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        echo "🐧 检测到Linux系统"
        if command -v systemctl &> /dev/null; then
            echo "🚀 启动Docker服务(systemd)..."
            sudo systemctl start docker
            
            # 等待Docker启动
            echo "⏳ 等待Docker服务启动，最多等待30秒..."
            for i in {1..6}; do
                sleep 5
                if docker info &> /dev/null; then
                    echo "✅ Docker服务已成功启动"
                    return 0
                fi
                echo "⏳ 等待Docker启动中... ($((i*5))秒)"
            done
        elif command -v service &> /dev/null; then
            echo "🚀 启动Docker服务(service)..."
            sudo service docker start
            
            # 等待Docker启动
            echo "⏳ 等待Docker服务启动，最多等待30秒..."
            for i in {1..6}; do
                sleep 5
                if docker info &> /dev/null; then
                    echo "✅ Docker服务已成功启动"
                    return 0
                fi
                echo "⏳ 等待Docker启动中... ($((i*5))秒)"
            done
        else
            echo "❌ 无法启动Docker服务，请手动启动"
            return 1
        fi
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
        # Windows
        echo "🪟 检测到Windows系统"
        if command -v powershell &> /dev/null; then
            echo "🚀 启动Docker Desktop..."
            powershell.exe -Command "Start-Process 'Docker Desktop'"
            
            # 等待Docker启动
            echo "⏳ 等待Docker服务启动，最多等待60秒..."
            for i in {1..12}; do
                sleep 5
                if docker info &> /dev/null; then
                    echo "✅ Docker服务已成功启动"
                    return 0
                fi
                echo "⏳ 等待Docker启动中... ($((i*5))秒)"
            done
        else
            echo "❌ 无法启动Docker Desktop，请手动启动"
            return 1
        fi
    else
        echo "❓ 未知操作系统，无法自动启动Docker服务"
        return 1
    fi
    
    echo "❌ Docker服务启动超时，请手动启动"
    return 1
}

# 默认参数
START_DOCKER=true
START_API=true
START_WEB=true
BACKGROUND=true
FORCE=false

# 解析命令行参数，仅当脚本被直接执行时
if [ "$SCRIPT_SOURCED" = false ]; then
    while [[ $# -gt 0 ]]; do
        case $1 in
            -a|--api-only)
                START_DOCKER=false
                START_API=true
                START_WEB=false
                shift
                ;;
            -w|--web-only)
                START_DOCKER=false
                START_API=false
                START_WEB=true
                shift
                ;;
            -m|--mcp-only)
                START_DOCKER=false
                START_API=false
                START_WEB=false
                shift
                ;;
            -d|--docker-only)
                START_DOCKER=true
                START_API=false
                START_WEB=false
                shift
                ;;
            -b|--background)
                BACKGROUND=true
                shift
                ;;
            -f|--force)
                FORCE=true
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

    echo "🚀 启动 Dify MCP 服务..."
fi

# 定义路径
MCP_BRIDGE_DIR="$DIFY_DIR/mcp-bridge"
DIFY_DATA_DIR="$PROJECT_ROOT/mcp/data/dify_data"

# 服务启动函数
start_docker_services() {
    echo "🐳 启动Docker中间件服务..."
    
    # 检查Docker daemon是否运行
    if ! docker info >/dev/null 2>&1; then
        echo "❌ Docker daemon未运行，请先启动Docker服务"
        return 1
    fi
    
    cd "$DIFY_DIR/docker"
    
    if [ ! -f "docker-compose.middleware.yaml" ]; then
        echo "❌ Docker Compose配置文件不存在"
        return 1
    fi
    
    # 启动中间件服务
    echo "🚀 启动Docker中间件服务..."
    docker compose -f docker-compose.middleware.yaml up -d
    if [ $? -ne 0 ]; then
        echo "❌ Docker中间件服务启动失败"
        return 1
    fi

    # 检查服务状态
    RUNNING_SERVICES=$(docker-compose -f docker-compose.middleware.yaml ps --services --filter "status=running")
    if [ -z "$RUNNING_SERVICES" ]; then
        echo "❌ 没有服务在运行"
        return 1
    fi
    
    echo "✅ Docker中间件服务启动成功"
    echo "   运行中的服务: $RUNNING_SERVICES"
    cd "$DIFY_DIR"
    return 0
}

start_api_service() {
    echo "🔧 启动Dify API服务..."
    cd "$DIFY_DIR/api"
    
    if [ ! -f ".env" ]; then
        echo "❌ API环境配置文件不存在"
        return 1
    fi
    
    # 检查虚拟环境和依赖
    if ! command -v uv &> /dev/null; then
        echo "❌ uv包管理器未安装"
        return 1
    fi
    
    # 设置环境变量
    export FLASK_APP=app.py
    export FLASK_ENV=development
    
    if [ "$BACKGROUND" = true ]; then
        echo "🔧 后台启动API服务..."
        nohup uv run flask run --host 0.0.0.0 --port=5001 > "$DIFY_DIR/logs/api.log" 2>&1 &
        API_PID=$!
        echo $API_PID > "$DIFY_DIR/logs/api.pid"
        echo "✅ API服务已在后台启动 (PID: $API_PID)"
        echo "   访问地址: http://127.0.0.1:5001/v1"
        echo "   日志文件: $DIFY_DIR/logs/api.log"
        
        # 启动Celery Worker
        echo "🔧 后台启动Celery Worker..."
        nohup uv run celery -A app.celery worker -P gevent -c 1 --loglevel INFO -Q dataset,generation,mail,ops_trace > "$DIFY_DIR/logs/celery.log" 2>&1 &
        
        CELERY_PID=$!
        echo $CELERY_PID > "$DIFY_DIR/logs/celery.pid"
        echo "✅ Celery Worker已在后台启动 (PID: $CELERY_PID)"
        echo "   日志文件: $DIFY_DIR/logs/celery.log"
    else
        echo "✅ API服务启动中..."
        echo "   访问地址: http://127.0.0.1:5001/v1"
        echo "   按 Ctrl+C 停止服务"
        echo ""
        echo "💡 注意: 需要在另一个终端启动Celery Worker:"
        echo "   cd $DIFY_DIR/api && uv run celery -A app.celery worker -P gevent -c 1"
        echo ""
        uv run flask run --host 0.0.0.0 --port=5001
    fi
    
    cd "$DIFY_DIR"
    return 0
}

start_web_service() {
    echo "🌐 启动Dify Web界面..."
    cd "$DIFY_DIR/web"
    
    if [ ! -d "node_modules" ]; then
        echo "❌ 前端依赖未安装，请先运行部署脚本"
        return 1
    fi
    
    if [ ! -f ".env.local" ]; then
        echo "❌ Web环境配置文件不存在"
        return 1
    fi
    
    if [ "$BACKGROUND" = true ]; then
        echo "🌐 后台启动Web界面..."
        nohup pnpm start > "$DIFY_DIR/logs/web.log" 2>&1 &
        WEB_PID=$!
        echo $WEB_PID > "$DIFY_DIR/logs/web.pid"
        echo "✅ Web界面已在后台启动 (PID: $WEB_PID)"
        echo "   访问地址: http://localhost:3000"
        echo "   日志文件: $DIFY_DIR/logs/web.log"
    else
        echo "✅ Web界面启动中..."
        echo "   访问地址: http://localhost:3000"
        echo "   按 Ctrl+C 停止服务"
        pnpm start
    fi
    
    cd "$DIFY_DIR"
    return 0
}

start_xinference_service() {
    echo "🤖 启动 Xinference 服务..."
    # 检查是否已在运行
    if pgrep -f "xinference-local" > /dev/null; then
        echo "✅ Xinference 已在运行"
        return 0
    fi
    # 检查虚拟环境
    if [ ! -d "$DIFY_DIR/.venv" ]; then
        echo "❌ 虚拟环境不存在，请先运行部署脚本"
        return 1
    fi
    # 只在这里激活虚拟环境
    source "$DIFY_DIR/.venv/bin/activate"
    nohup xinference-local > "$DIFY_DIR/logs/xinference.log" 2>&1 &
    XINFERENCE_PID=$!
    echo $XINFERENCE_PID > "$DIFY_DIR/logs/xinference.pid"
    deactivate
    echo "✅ Xinference 已在后台启动 (PID: $XINFERENCE_PID)"
    echo "   访问地址: http://127.0.0.1:9997"
    echo "   日志文件: $DIFY_DIR/logs/xinference.log"
    echo "   10秒后启动xinference模型: bge-reranker-large"
    (
        sleep 10
        source "$DIFY_DIR/.venv/bin/activate"
        xinference launch --model-name bge-reranker-large --model-type rerank >> "$DIFY_DIR/logs/xinference_model.log" 2>&1 &
        deactivate
    ) &

    return 0
}

# 以下是主要执行逻辑，仅当脚本被直接执行时运行
if [ "$SCRIPT_SOURCED" = false ]; then
    # 检查环境
    echo "🔍 检查运行环境..."

    # 检查基本目录结构
    if [ ! -d "$DIFY_DIR" ] && [ "$START_API" = true -o "$START_WEB" = true ]; then
        echo "❌ Dify项目目录不存在，请先运行部署脚本: ./scripts/deploy.sh"
        exit 1
    fi

    # 检查Docker服务
    if [ "$START_DOCKER" = true ] || [ "$START_API" = true ]; then
        if ! command -v docker &> /dev/null; then
            echo "❌ Docker未安装"
            exit 1
        fi
        
        if ! docker info &> /dev/null; then
            echo "🔄 Docker服务未运行，尝试自动启动..."
            if ! start_docker_daemon; then
                echo "❌ 无法自动启动Docker服务，请手动启动Docker后再运行脚本"
            exit 1
            fi
        fi
        echo "✅ Docker服务正常"
    fi

    # 创建数据目录
    mkdir -p "$DIFY_DATA_DIR"

    # 创建日志目录
    mkdir -p "$DIFY_DIR/logs"

    # 加载环境变量
    if [ -f "$DIFY_DIR/.env" ]; then
        source "$DIFY_DIR/.env"
    fi

    # 按顺序启动服务
    FAILED_SERVICES=()

    # 1. 启动Docker中间件（如果需要）
    if [ "$START_DOCKER" = true ]; then
        if ! start_docker_services; then
            FAILED_SERVICES+=("Docker中间件")
        fi
    fi

    # 1.5 启动 Xinference 服务
    if ! start_xinference_service; then
        FAILED_SERVICES+=("Xinference")
    fi

    # 2. 启动API服务（如果需要）
    if [ "$START_API" = true ]; then
        if ! start_api_service; then
            FAILED_SERVICES+=("API服务")
        fi
    fi

    # 3. 启动Web界面（如果需要）
    if [ "$START_WEB" = true ]; then
        if ! start_web_service; then
            FAILED_SERVICES+=("Web界面")
        fi
    fi

    # 显示启动结果
    echo ""
    if [ ${#FAILED_SERVICES[@]} -eq 0 ]; then
        echo "🎉 Dify MCP 启动完成!"
        echo ""
        echo "📋 服务状态:"
        
        if [ "$START_DOCKER" = true ]; then
            echo "   🐳 Docker中间件: 运行中"
        fi
        
        if [ "$START_API" = true ]; then
            echo "   🔧 API服务: http://localhost:5001/v1"
        fi
        
        if [ "$START_WEB" = true ]; then
            echo "   🌐 Web界面: http://localhost:3000"
        fi
        
        if [ "$BACKGROUND" = true ]; then
            echo ""
            echo "📄 日志文件:"
            [ "$START_API" = true ] && echo "   API服务: $DIFY_DIR/logs/api.log"
            [ "$START_API" = true ] && echo "   Celery Worker: $DIFY_DIR/logs/celery.log"
            [ "$START_WEB" = true ] && echo "   Web界面: $DIFY_DIR/logs/web.log"
            echo ""
            echo "🛑 停止服务:"
            echo "   执行: ./scripts/stop.sh"
        fi
        
        echo ""
        echo "💡 提示:"
        echo "   - 可以使用test.sh脚本测试服务: ./scripts/test.sh"
        
    else
        echo "❌ 部分服务启动失败:"
        for service in "${FAILED_SERVICES[@]}"; do
            echo "   - $service"
        done
        echo ""
        echo "🔍 请检查错误信息和依赖环境"
        exit 1
    fi
fi