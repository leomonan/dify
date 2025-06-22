#!/usr/bin/env python3
"""
创建日期：2025年1月28日星期二 21:45:00
最后更新日期：2025年1月28日星期二 21:45:00

Dify MCP Bridge Server
为 Cursor IDE 提供 Dify 知识库查询功能
"""

import asyncio
import json
import logging
import os
import sys
from typing import Any, Dict, List, Optional

from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import (
    Resource,
    Tool,
    TextContent,
    ImageContent,
    EmbeddedResource,
    LoggingLevel
)

from dify_integration.api_client import DifyAPIClient

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class DifyMCPServer:
    def __init__(self):
        self.server = Server("dify-knowledge")
        self.client: Optional[DifyAPIClient] = None
        self._setup_tools()

    def _setup_tools(self):
        """设置 MCP 工具"""
        
        @self.server.list_tools()
        async def handle_list_tools() -> List[Tool]:
            """列出可用的工具"""
            return [
                Tool(
                    name="dify_list_datasets",
                    description="列出 Dify 中的所有知识库数据集",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "page": {
                                "type": "integer",
                                "description": "页码（从1开始）",
                                "default": 1
                            },
                            "limit": {
                                "type": "integer", 
                                "description": "每页数量",
                                "default": 20
                            }
                        }
                    }
                ),
                Tool(
                    name="dify_search_knowledge",
                    description="在 Dify 知识库中搜索相关信息",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "query": {
                                "type": "string",
                                "description": "搜索查询内容"
                            },
                            "dataset_ids": {
                                "type": "array",
                                "items": {"type": "string"},
                                "description": "要搜索的数据集ID列表（可选，默认搜索所有）"
                            },
                            "top_k": {
                                "type": "integer",
                                "description": "每个数据集返回的结果数量",
                                "default": 3
                            }
                        },
                        "required": ["query"]
                    }
                ),
                Tool(
                    name="dify_get_dataset_info",
                    description="获取指定数据集的详细信息",
                    inputSchema={
                        "type": "object", 
                        "properties": {
                            "dataset_id": {
                                "type": "string",
                                "description": "数据集ID"
                            }
                        },
                        "required": ["dataset_id"]
                    }
                ),
                Tool(
                    name="dify_search_documents",
                    description="在指定数据集中搜索文档",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "dataset_id": {
                                "type": "string",
                                "description": "数据集ID"
                            },
                            "keyword": {
                                "type": "string", 
                                "description": "搜索关键词（可选）"
                            },
                            "page": {
                                "type": "integer",
                                "description": "页码",
                                "default": 1
                            },
                            "limit": {
                                "type": "integer",
                                "description": "每页数量",
                                "default": 20
                            }
                        },
                        "required": ["dataset_id"]
                    }
                )
            ]

        @self.server.call_tool()
        async def handle_call_tool(name: str, arguments: Dict[str, Any]) -> List[TextContent]:
            """处理工具调用"""
            try:
                if not self.client:
                    # 从环境变量获取配置
                    api_url = os.getenv("DIFY_API_URL", "http://localhost:5001")
                    api_key = os.getenv("DIFY_API_KEY")
                    
                    if not api_key:
                        return [TextContent(
                            type="text",
                            text="❌ 错误: 未配置 DIFY_API_KEY 环境变量"
                        )]
                    
                    self.client = DifyAPIClient(base_url=api_url, api_key=api_key)

                if name == "dify_list_datasets":
                    return await self._handle_list_datasets(arguments)
                elif name == "dify_search_knowledge":
                    return await self._handle_search_knowledge(arguments)
                elif name == "dify_get_dataset_info":
                    return await self._handle_get_dataset_info(arguments)
                elif name == "dify_search_documents":
                    return await self._handle_search_documents(arguments)
                else:
                    return [TextContent(
                        type="text",
                        text=f"❌ 未知工具: {name}"
                    )]
                    
            except Exception as e:
                logger.error(f"Tool call failed: {e}")
                return [TextContent(
                    type="text",
                    text=f"❌ 工具执行失败: {str(e)}"
                )]

    async def _handle_list_datasets(self, arguments: Dict[str, Any]) -> List[TextContent]:
        """处理数据集列表请求"""
        page = arguments.get("page", 1)
        limit = arguments.get("limit", 20)
        
        response = await self.client.get_datasets(page=page, limit=limit)
        datasets = response.get("data", [])
        
        if not datasets:
            return [TextContent(
                type="text",
                text="📚 未找到任何数据集"
            )]
        
        result = "📚 **Dify 知识库数据集列表**\n\n"
        for i, dataset in enumerate(datasets, 1):
            name = dataset.get("name", "未命名")
            dataset_id = dataset.get("id", "")
            doc_count = dataset.get("document_count", 0)
            description = dataset.get("description", "无描述")
            
            result += f"**{i}. {name}**\n"
            result += f"   - ID: `{dataset_id}`\n"
            result += f"   - 文档数量: {doc_count}\n"
            result += f"   - 描述: {description}\n\n"
        
        return [TextContent(type="text", text=result)]

    async def _handle_search_knowledge(self, arguments: Dict[str, Any]) -> List[TextContent]:
        """处理知识库搜索请求"""
        query = arguments["query"]
        dataset_ids = arguments.get("dataset_ids")
        top_k = arguments.get("top_k", 3)
        
        results = await self.client.multi_dataset_search(
            query=query,
            dataset_ids=dataset_ids,
            limit_per_dataset=top_k
        )
        
        if not results:
            return [TextContent(
                type="text",
                text=f"🔍 在知识库中搜索 '{query}' 未找到相关结果"
            )]
        
        result_text = f"🔍 **搜索结果: '{query}'**\n\n"
        
        for search_result in results:
            if not search_result.get("success"):
                continue
                
            dataset_id = search_result["dataset_id"]
            data = search_result["result"].get("records", [])
            
            if data:
                # 获取数据集名称
                try:
                    dataset_info = await self.client.get_dataset(dataset_id)
                    dataset_name = dataset_info.get("name", dataset_id)
                except:
                    dataset_name = dataset_id
                
                result_text += f"### 📖 {dataset_name}\n\n"
                
                for i, record in enumerate(data[:top_k], 1):
                    score = record.get("score", 0.0)
                    content = record.get("content", "")
                    
                    # 截断过长的内容
                    if len(content) > 200:
                        content = content[:200] + "..."
                    
                    result_text += f"**{i}. 相关度: {score:.3f}**\n"
                    result_text += f"```\n{content}\n```\n\n"
        
        return [TextContent(type="text", text=result_text)]

    async def _handle_get_dataset_info(self, arguments: Dict[str, Any]) -> List[TextContent]:
        """处理获取数据集信息请求"""
        dataset_id = arguments["dataset_id"]
        
        dataset_info = await self.client.get_dataset(dataset_id)
        
        name = dataset_info.get("name", "未命名")
        description = dataset_info.get("description", "无描述") 
        doc_count = dataset_info.get("document_count", 0)
        created_at = dataset_info.get("created_at", "")
        
        result = f"📚 **数据集信息**\n\n"
        result += f"**名称**: {name}\n"
        result += f"**ID**: `{dataset_id}`\n"
        result += f"**描述**: {description}\n"
        result += f"**文档数量**: {doc_count}\n"
        result += f"**创建时间**: {created_at}\n"
        
        return [TextContent(type="text", text=result)]

    async def _handle_search_documents(self, arguments: Dict[str, Any]) -> List[TextContent]:
        """处理文档搜索请求"""
        dataset_id = arguments["dataset_id"]
        keyword = arguments.get("keyword")
        page = arguments.get("page", 1)
        limit = arguments.get("limit", 20)
        
        response = await self.client.get_dataset_documents(
            dataset_id=dataset_id,
            keyword=keyword,
            page=page,
            limit=limit
        )
        
        documents = response.get("data", [])
        
        if not documents:
            search_info = f"关键词: '{keyword}'" if keyword else "所有文档"
            return [TextContent(
                type="text",
                text=f"📄 在数据集中搜索 {search_info} 未找到文档"
            )]
        
        result = f"📄 **文档搜索结果**\n\n"
        if keyword:
            result += f"搜索关键词: `{keyword}`\n\n"
        
        for i, doc in enumerate(documents, 1):
            name = doc.get("name", "未命名")
            doc_id = doc.get("id", "")
            word_count = doc.get("word_count", 0)
            updated_at = doc.get("updated_at", "")
            
            result += f"**{i}. {name}**\n"
            result += f"   - ID: `{doc_id}`\n"
            result += f"   - 字数: {word_count}\n"
            result += f"   - 更新时间: {updated_at}\n\n"
        
        return [TextContent(type="text", text=result)]

    async def cleanup(self):
        """清理资源"""
        if self.client:
            await self.client.close()

async def main():
    """主函数"""
    logger.info("🚀 启动 Dify MCP Bridge Server...")
    
    server_instance = DifyMCPServer()
    
    try:
        async with stdio_server() as (read_stream, write_stream):
            await server_instance.server.run(
                read_stream,
                write_stream,
                server_instance.server.create_initialization_options()
            )
    except KeyboardInterrupt:
        logger.info("收到中断信号，正在关闭服务器...")
    except Exception as e:
        logger.error(f"服务器运行出错: {e}")
    finally:
        await server_instance.cleanup()
        logger.info("服务器已关闭")

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n👋 Dify MCP Bridge Server 已停止")
    except Exception as e:
        print(f"❌ 启动失败: {e}")
        sys.exit(1) 