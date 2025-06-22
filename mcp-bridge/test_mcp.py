#!/usr/bin/env python3
"""
测试 MCP 工具功能
"""
import asyncio
import os
import sys
from src.dify_integration.api_client import DifyAPIClient

async def test_dify_tools():
    """测试 Dify 工具功能"""
    print("🧪 测试 Dify MCP 工具功能")
    
    # 设置环境变量
    api_url = "http://localhost:5001"
    api_key = "dataset-Cum968WkXxtIp8RImIrjTUNA"
    
    print(f"API URL: {api_url}")
    print(f"API Key: {api_key[:12]}...")
    
    # 创建客户端
    client = DifyAPIClient(base_url=api_url, api_key=api_key)
    
    try:
        # 测试 1: 列出数据集
        print("\n📋 测试 1: 列出数据集")
        datasets = await client.get_datasets(page=1, limit=5)
        print(f"✅ 成功获取数据集: {len(datasets.get('data', []))} 个")
        
        if datasets.get('data'):
            dataset_id = datasets['data'][0]['id']
            print(f"📄 使用数据集ID: {dataset_id}")
            
            # 测试 2: 获取数据集详情
            print("\n📄 测试 2: 获取数据集详情")
            dataset_info = await client.get_dataset(dataset_id)
            print(f"✅ 数据集名称: {dataset_info.get('name', 'Unknown')}")
            
            # 测试 3: 搜索知识库
            print("\n🔍 测试 3: 搜索知识库")
            search_results = await client.search_dataset(dataset_id, "测试查询")
            records = search_results.get('records', [])
            print(f"✅ 找到 {len(records)} 个搜索结果")
            
            # 测试 4: 多数据集搜索
            print("\n🔍 测试 4: 多数据集搜索")
            multi_results = await client.multi_dataset_search("测试", limit_per_dataset=2)
            print(f"✅ 多数据集搜索完成，{len(multi_results)} 个数据集有结果")
            
        print("\n✅ 所有测试完成!")
        
    except Exception as e:
        print(f"❌ 测试失败: {e}")
        import traceback
        traceback.print_exc()
    
    finally:
        await client.close()

if __name__ == "__main__":
    asyncio.run(test_dify_tools()) 