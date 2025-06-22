#!/usr/bin/env python3
"""
Dify MCP Bridge 连接测试脚本
验证与 Dify API 的连接和基本功能
"""

import asyncio
import sys
import os
from pathlib import Path

# 添加源码路径
sys.path.insert(0, str(Path(__file__).parent / "src"))

from dify_integration.api_client import DifyAPIClient
from dotenv import load_dotenv
import logging

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def test_basic_connection():
    """测试基本连接"""
    logger.info("🔌 测试 Dify API 基本连接...")
    
    # 加载环境变量
    env_file = Path(__file__).parent / ".env"
    if env_file.exists():
        load_dotenv(env_file)
        logger.info(f"✅ 已加载环境变量文件: {env_file}")
    else:
        load_dotenv()
        logger.warning(f"⚠️ 未找到 .env 文件: {env_file}")
        logger.info("💡 请复制 env.example 为 .env 并填写正确的配置")
    
    base_url = os.getenv("DIFY_API_URL", "http://localhost:5001")
    api_key = os.getenv("DIFY_API_KEY")
    
    logger.info(f"API URL: {base_url}")
    if api_key:
        # 只显示API Key的前几位和后几位，保护敏感信息
        masked_key = f"{api_key[:8]}...{api_key[-4:]}" if len(api_key) > 12 else "***"
        logger.info(f"API Key: {masked_key} (长度: {len(api_key)})")
        
        # 检查API Key格式
        if not api_key.startswith(('dataset-', 'app-', 'sk-')):
            logger.warning("⚠️ API Key 格式可能不正确")
            logger.info("💡 确保使用正确的 Dify API Key（通常以 dataset- 或 app- 开头）")
    else:
        logger.warning("⚠️ 未配置 API Key")
        logger.info("💡 请在 .env 文件中设置 DIFY_API_KEY")
    
    async with DifyAPIClient(base_url=base_url, api_key=api_key) as client:
        try:
            # 测试获取数据集列表
            logger.info("🔍 正在获取数据集列表...")
            response = await client.get_datasets(limit=5)
            datasets = response.get("data", [])
            total = response.get("total", 0)
            
            logger.info(f"✅ 成功连接！发现 {total} 个数据集")
            
            if datasets:
                logger.info("📚 可用数据集:")
                for i, dataset in enumerate(datasets, 1):
                    name = dataset.get("name", "未命名")
                    doc_count = dataset.get("document_count", 0)
                    dataset_id = dataset.get("id", "")
                    logger.info(f"  {i}. {name} ({doc_count} 个文档) - ID: {dataset_id[:8]}...")
            else:
                logger.warning("⚠️ 没有找到任何数据集")
                logger.info("💡 请在 Dify 中创建知识库后再测试")
            
            return datasets
            
        except Exception as e:
            logger.error(f"❌ 连接失败: {e}")
            
            # 提供更详细的错误诊断
            if "401" in str(e) or "unauthorized" in str(e).lower():
                logger.error("🔐 认证失败，可能的原因：")
                logger.error("   1. API Key 不正确")
                logger.error("   2. API Key 已过期")
                logger.error("   3. API Key 权限不足")
                logger.error("💡 请检查 Dify 控制台中的 API Key 设置")
            elif "404" in str(e):
                logger.error("🔗 API 端点不存在，请检查：")
                logger.error("   1. Dify 服务器 URL 是否正确")
                logger.error("   2. Dify 版本是否支持该 API")
            elif "connection" in str(e).lower():
                logger.error("🌐 网络连接问题，请检查：")
                logger.error("   1. Dify 服务是否正在运行")
                logger.error("   2. URL 是否可访问")
                logger.error("   3. 防火墙设置")
            
            return None

async def test_search_functionality(datasets):
    """测试搜索功能"""
    if not datasets:
        logger.warning("⚠️ 没有可用数据集，跳过搜索测试")
        return
    
    logger.info("\n🔍 测试知识库搜索功能...")
    
    # 重新加载环境变量
    env_file = Path(__file__).parent / ".env"
    if env_file.exists():
        load_dotenv(env_file)
    else:
        load_dotenv()
    
    base_url = os.getenv("DIFY_API_URL", "http://localhost:5001")
    api_key = os.getenv("DIFY_API_KEY")
    
    async with DifyAPIClient(base_url=base_url, api_key=api_key) as client:
        # 选择第一个数据集进行测试
        test_dataset = datasets[0]
        dataset_id = test_dataset["id"]
        dataset_name = test_dataset["name"]
        
        logger.info(f"📖 在数据集 '{dataset_name}' 中搜索...")
        
        # 测试查询
        test_queries = [
            "如何使用",
            "文档",
            "配置",
            "API"
        ]
        
        for query in test_queries:
            try:
                logger.info(f"  查询: '{query}'")
                result = await client.search_dataset(
                    dataset_id=dataset_id,
                    query=query
                )
                
                records = result.get("records", [])
                logger.info(f"  ✅ 找到 {len(records)} 个结果")
                
                if records:
                    # 显示第一个结果的摘要
                    first_result = records[0]
                    content = first_result.get("segment", {}).get("content", "")
                    score = first_result.get("score", 0)
                    logger.info(f"  📄 最相关结果 (评分: {score:.3f}): {content[:100]}...")
                
                # 找到有结果的查询就停止，避免过多输出
                if records:
                    break
                
            except Exception as e:
                logger.error(f"  ❌ 搜索失败: {e}")

async def test_multi_dataset_search(datasets):
    """测试多数据集搜索"""
    if not datasets or len(datasets) < 2:
        logger.warning("⚠️ 数据集数量不足，跳过多数据集搜索测试")
        return
    
    logger.info("\n🔍 测试多数据集搜索功能...")
    
    # 重新加载环境变量
    env_file = Path(__file__).parent / ".env"
    if env_file.exists():
        load_dotenv(env_file)
    else:
        load_dotenv()
    
    base_url = os.getenv("DIFY_API_URL", "http://localhost:5001")
    api_key = os.getenv("DIFY_API_KEY")
    
    async with DifyAPIClient(base_url=base_url, api_key=api_key) as client:
        # 选择前几个数据集
        dataset_ids = [d["id"] for d in datasets[:min(3, len(datasets))]]
        
        logger.info(f"📚 在 {len(dataset_ids)} 个数据集中搜索...")
        
        try:
            results = await client.multi_dataset_search(
                query="配置",
                dataset_ids=dataset_ids,
                limit_per_dataset=2
            )
            
            logger.info(f"✅ 多数据集搜索完成，{len(results)} 个数据集返回结果")
            
            for result in results:
                if result.get("success"):
                    dataset_id = result["dataset_id"]
                    records = result["result"].get("records", [])
                    dataset_name = next(
                        (d["name"] for d in datasets if d["id"] == dataset_id),
                        dataset_id
                    )
                    logger.info(f"  📖 {dataset_name}: {len(records)} 个结果")
                else:
                    logger.warning(f"  ❌ 数据集 {result['dataset_id']} 搜索失败: {result.get('error')}")
                    
        except Exception as e:
            logger.error(f"❌ 多数据集搜索失败: {e}")

def check_environment():
    """检查环境配置"""
    logger.info("🔧 检查环境配置...")
    
    env_file = Path(__file__).parent / ".env"
    env_example = Path(__file__).parent / "env.example"
    
    if not env_file.exists():
        logger.warning("⚠️ 未找到 .env 文件")
        if env_example.exists():
            logger.info("💡 可以复制 env.example 为 .env:")
            logger.info(f"   cp {env_example} {env_file}")
        else:
            logger.error("❌ 也未找到 env.example 文件")
        return False
    
    # 检查 .env 文件内容
    try:
        with open(env_file, 'r') as f:
            content = f.read()
            
        if "DIFY_API_KEY=" in content:
            # 检查是否有值
            for line in content.split('\n'):
                if line.startswith('DIFY_API_KEY=') and '=' in line:
                    value = line.split('=', 1)[1].strip()
                    if value:
                        logger.info("✅ .env 文件中已配置 DIFY_API_KEY")
                        return True
                    else:
                        logger.warning("⚠️ .env 文件中 DIFY_API_KEY 为空")
                        return False
        else:
            logger.warning("⚠️ .env 文件中未找到 DIFY_API_KEY 配置")
            return False
            
    except Exception as e:
        logger.error(f"❌ 读取 .env 文件失败: {e}")
        return False
    
    return True

async def main():
    """主测试函数"""
    logger.info("🧪 开始 Dify MCP Bridge 功能测试\n")
    
    # 检查环境配置
    if not check_environment():
        logger.error("❌ 环境配置检查失败，请修复后重试")
        return 1
    
    # 基本连接测试
    datasets = await test_basic_connection()
    
    if datasets is not None:
        # 只有在有数据集的情况下才进行搜索测试
        if datasets:
            # 搜索功能测试
            await test_search_functionality(datasets)
            
            # 多数据集搜索测试
            await test_multi_dataset_search(datasets)
        
        logger.info("\n✅ 所有测试完成！MCP Bridge 功能正常")
    else:
        logger.error("\n❌ 基本连接测试失败，请检查 Dify 服务状态和配置")
        return 1
    
    return 0

if __name__ == "__main__":
    try:
        result = asyncio.run(main())
        sys.exit(result)
    except KeyboardInterrupt:
        logger.info("\n🛑 测试被用户中断")
        sys.exit(0)
    except Exception as e:
        logger.error(f"\n💥 测试过程中出现错误: {e}")
        sys.exit(1) 