#!/usr/bin/env python3
"""
Dify MCP Bridge 环境配置助手
帮助用户创建和配置 .env 文件
"""

import os
from pathlib import Path

def main():
    """主函数"""
    print("🔧 Dify MCP Bridge 环境配置助手")
    print("=" * 50)
    
    # 检查是否已存在 .env 文件
    env_file = Path(".env")
    env_example = Path("env.example")
    
    if env_file.exists():
        print(f"✅ 发现现有的 .env 文件: {env_file}")
        response = input("是否要重新配置？(y/N): ").strip().lower()
        if response not in ['y', 'yes']:
            print("👋 配置取消")
            return
    
    # 复制示例文件
    if env_example.exists():
        print(f"📋 从 {env_example} 复制配置模板...")
        with open(env_example, 'r') as f:
            template = f.read()
    else:
        print("⚠️ 未找到 env.example，使用默认模板")
        template = """# Dify MCP Bridge 配置文件

# Dify API 配置
DIFY_API_URL=http://127.0.0.1:5001/v1
DIFY_API_KEY=

# 日志级别
LOG_LEVEL=INFO

# MCP 服务器配置
MCP_SERVER_NAME=dify-knowledge-bridge
"""
    
    print("\n📝 请提供以下配置信息：")
    
    # 获取 Dify API URL
    default_url = "http://127.0.0.1:5001/v1"
    api_url = input(f"Dify API URL (默认: {default_url}): ").strip()
    if not api_url:
        api_url = default_url
    
    # 获取 API Key
    print("\n🔑 API Key 获取方法：")
    print("1. 登录 Dify 管理后台")
    print("2. 进入 '知识库' 页面")
    print("3. 点击右上角的 'API' 按钮")
    print("4. 复制 'API Key'")
    print("5. API Key 通常以 'dataset-' 开头")
    
    api_key = input("\nDify API Key: ").strip()
    
    if not api_key:
        print("⚠️ 警告：未设置 API Key，某些功能可能无法使用")
    
    # 生成 .env 文件内容
    env_content = template.replace("DIFY_API_URL=http://127.0.0.1:5001/v1", f"DIFY_API_URL={api_url}")
    env_content = env_content.replace("DIFY_API_KEY=", f"DIFY_API_KEY={api_key}")
    
    # 写入 .env 文件
    try:
        with open(env_file, 'w') as f:
            f.write(env_content)
        
        print(f"\n✅ 配置文件已创建: {env_file}")
        print("\n📋 配置摘要：")
        print(f"   API URL: {api_url}")
        print(f"   API Key: {'已设置' if api_key else '未设置'}")
        
        if api_key:
            # 验证 API Key 格式
            if api_key.startswith(('dataset-', 'app-', 'sk-')):
                print("   格式: ✅ 看起来正确")
            else:
                print("   格式: ⚠️ 可能不正确，请确认")
        
        print(f"\n🧪 现在可以运行测试：")
        print(f"   python test_connection.py")
        
    except Exception as e:
        print(f"❌ 创建配置文件失败: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    try:
        result = main()
        exit(result)
    except KeyboardInterrupt:
        print("\n👋 配置取消")
        exit(0)
    except Exception as e:
        print(f"\n💥 配置过程中出现错误: {e}")
        exit(1) 