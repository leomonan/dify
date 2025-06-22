#!/usr/bin/env python3
"""
Dify MCP Bridge 启动脚本
用于开发和测试环境的便捷启动
"""

import os
import sys
import subprocess
import logging
from pathlib import Path

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def check_requirements():
    """检查依赖是否已安装"""
    try:
        import aiohttp
        import fastmcp
        import mcp
        import dotenv
        logger.info("✅ 所有依赖已安装")
        return True
    except ImportError as e:
        logger.error(f"❌ 缺少依赖: {e}")
        logger.info("请运行: pip install -r requirements.txt")
        return False

def check_dify_connection():
    """检查 Dify 服务是否可访问"""
    import requests
    
    dify_url = os.getenv("DIFY_API_URL", "http://localhost:5001")
    try:
        response = requests.get(f"{dify_url}/health", timeout=5)
        if response.status_code == 200:
            logger.info(f"✅ Dify 服务连接成功: {dify_url}")
            return True
    except:
        pass
    
    # 尝试连接到控制台 API
    try:
        # 这里应该使用实际可用的端点
        response = requests.get(f"{dify_url}/console/api/setup", timeout=5)
        logger.info(f"✅ Dify 控制台 API 可访问: {dify_url}")
        return True
    except Exception as e:
        logger.warning(f"⚠️ 无法连接到 Dify 服务 {dify_url}: {e}")
        logger.info("请确保 Dify 服务正在运行")
        return False

def setup_environment():
    """设置环境变量"""
    env_file = Path(__file__).parent / ".env"
    env_example = Path(__file__).parent / "env.example"
    
    if not env_file.exists() and env_example.exists():
        logger.info("🔧 创建 .env 文件...")
        import shutil
        shutil.copy(env_example, env_file)
        logger.info(f"✅ 已创建 {env_file}，请根据需要修改配置")
    
    # 加载环境变量
    from dotenv import load_dotenv
    load_dotenv(env_file)

def main():
    """主函数"""
    logger.info("🚀 启动 Dify MCP Bridge Server...")
    
    # 设置环境
    setup_environment()
    
    # 检查依赖
    if not check_requirements():
        sys.exit(1)
    
    # 检查 Dify 连接
    check_dify_connection()
    
    # 启动服务器
    server_path = Path(__file__).parent / "src" / "mcp_server.py"
    
    logger.info(f"📍 服务器路径: {server_path}")
    logger.info("🎯 启动 MCP 服务器 (使用 stdio 传输)...")
    logger.info("💡 提示: 使用 Ctrl+C 停止服务器")
    
    try:
        # 运行服务器
        result = subprocess.run([
            sys.executable, 
            str(server_path)
        ], cwd=str(server_path.parent))
        
        return result.returncode
        
    except KeyboardInterrupt:
        logger.info("\n🛑 服务器已停止")
        return 0
    except Exception as e:
        logger.error(f"❌ 启动失败: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(main()) 