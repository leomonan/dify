#!/usr/bin/env python3
"""
创建日期：2025年1月28日星期二 21:45:00
最后更新日期：2025年6月23日星期一 15:16:00

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
                            },
                            "retrieval_model": {
                                "type": "string",
                                "description": "检索模型"
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
                    description="获取指定数据集中的文档列表（仅返回文档元数据，不含文档内容）",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "dataset_id": {
                                "type": "string",
                                "description": "数据集ID"
                            },
                            "keyword": {
                                "type": "string", 
                                "description": "文档名称搜索关键词（可选，仅匹配文档名）"
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
                ),
                Tool(
                    name="dify_create_dataset",
                    description="创建新的Dify知识库数据集",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "name": {
                                "type": "string",
                                "description": "知识库名称"
                            },
                            "description": {
                                "type": "string",
                                "description": "知识库描述",
                                "default": ""
                            },
                            "indexing_technique": {
                                "type": "string",
                                "description": "索引方式",
                                "enum": ["high_quality", "economy"],
                                "default": "high_quality"
                            },
                            "permission": {
                                "type": "string",
                                "description": "权限设置",
                                "enum": ["only_me", "all_team_members", "partial_members"],
                                "default": "only_me"
                            },
                            "embedding_model": {
                                "type": "string",
                                "description": "Embedding模型名称（可选）"
                            },
                            "embedding_model_provider": {
                                "type": "string",
                                "description": "Embedding模型供应商（可选）"
                            }
                        },
                        "required": ["name"]
                    }
                ),
                Tool(
                    name="dify_create_document",
                    description="向Dify知识库添加文档",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "dataset_id": {
                                "type": "string",
                                "description": "知识库ID"
                            },
                            "name": {
                                "type": "string",
                                "description": "文档名称"
                            },
                            "text": {
                                "type": "string",
                                "description": "文档内容"
                            },
                            "indexing_technique": {
                                "type": "string",
                                "description": "索引方式",
                                "enum": ["high_quality", "economy"],
                                "default": "high_quality"
                            },
                            "doc_form": {
                                "type": "string",
                                "description": "文档形式",
                                "enum": ["text_model", "hierarchical_model", "qa_model"],
                                "default": "text_model"
                            },
                            "doc_language": {
                                "type": "string",
                                "description": "文档语言",
                                "default": "Chinese"
                            }
                        },
                        "required": ["dataset_id", "name", "text"]
                    }
                ),
                Tool(
                    name="dify_get_indexing_status",
                    description="获取文档索引状态",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "dataset_id": {
                                "type": "string",
                                "description": "知识库ID"
                            },
                            "batch": {
                                "type": "string",
                                "description": "批次号"
                            }
                        },
                        "required": ["dataset_id", "batch"]
                    }
                )
            ]

        @self.server.call_tool()
        async def handle_call_tool(name: str, arguments: Dict[str, Any]) -> List[TextContent]:
            """处理工具调用"""
            try:
                if not self.client:
                    # 从环境变量获取配置
                    api_url = os.getenv("DIFY_API_URL", "http://127.0.0.1:5001/v1")
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
                elif name == "dify_create_dataset":
                    return await self._handle_create_dataset(arguments)
                elif name == "dify_create_document":
                    return await self._handle_create_document(arguments)
                elif name == "dify_get_indexing_status":
                    return await self._handle_get_indexing_status(arguments)
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
        retrieval_model = arguments.get("retrieval_model")  # 获取检索模型参数
        
        results = await self.client.multi_dataset_search(
            query=query,
            dataset_ids=dataset_ids,
            retrieval_model=retrieval_model,  # 传递检索模型参数
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
                    segment = record.get("segment", {})
                    content = segment.get("content", "")
                    doc_info = segment.get("document", {})
                    doc_name = doc_info.get("name", "未知文档")
                    
                    # 截断过长的内容
                    if len(content) > 200:
                        content = content[:200] + "..."
                    
                    result_text += f"**{i}. {doc_name} (相关度: {score:.5f})**\n"
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
        """获取数据集中的文档列表（仅返回元数据，不含文档内容）"""
        dataset_id = arguments["dataset_id"]
        keyword = arguments.get("keyword")
        page = arguments.get("page", 1)
        limit = arguments.get("limit", 20)
        
        try:
            # 获取数据集名称以提供更友好的输出
            dataset_info = await self.client.get_dataset(dataset_id)
            dataset_name = dataset_info.get("name", dataset_id)
        except:
            dataset_name = dataset_id
        
        response = await self.client.get_dataset_documents(
            dataset_id=dataset_id,
            keyword=keyword,
            page=page,
            limit=limit
        )
        
        documents = response.get("data", [])
        total = response.get("total", 0)
        
        if not documents:
            search_info = f"关键词: '{keyword}'" if keyword else "所有文档"
            return [TextContent(
                type="text",
                text=f"📄 在数据集中搜索 {search_info} 未找到文档"
            )]
        
        result = f"📑 **数据集「{dataset_name}」文档列表**\n\n"
        if keyword:
            result += f"🔍 文件名筛选: `{keyword}`\n"
        
        result += f"📊 当前页: {page}, 每页: {limit}, 总计: {total} 个文档\n\n"
        
        for i, doc in enumerate(documents, 1):
            name = doc.get("name", "未命名")
            doc_id = doc.get("id", "")
            word_count = doc.get("word_count", 0)
            updated_at = doc.get("updated_at", "")
            doc_type = doc.get("data_source_type", "未知类型")
            status = doc.get("indexing_status", "未知状态")
            
            result += f"**{i}. {name}**\n"
            result += f"   - ID: `{doc_id}`\n"
            result += f"   - 类型: {doc_type}\n"
            result += f"   - 字数: {word_count}\n"
            result += f"   - 索引状态: {status}\n"
            result += f"   - 更新时间: {updated_at}\n\n"
        
        result += "⚠️ **注意**: 此API仅返回文档元数据，不包含文档内容。如需搜索文档内容，请使用`dify_search_knowledge`工具。\n"
        
        return [TextContent(type="text", text=result)]

    async def _handle_create_dataset(self, arguments: Dict[str, Any]) -> List[TextContent]:
        """处理创建数据集请求"""
        name = arguments["name"]
        description = arguments.get("description", "")
        indexing_technique = arguments.get("indexing_technique", "high_quality")
        permission = arguments.get("permission", "only_me")
        embedding_model = arguments.get("embedding_model")
        embedding_model_provider = arguments.get("embedding_model_provider")
        
        try:
            dataset = await self.client.create_dataset(
                name=name,
                description=description,
                indexing_technique=indexing_technique,
                permission=permission,
                embedding_model=embedding_model,
                embedding_model_provider=embedding_model_provider
            )
            
            result = f"✅ **知识库创建成功**\n\n"
            result += f"**名称**: {dataset.get('name', '未知')}\n"
            result += f"**ID**: `{dataset.get('id', '')}`\n"
            result += f"**描述**: {dataset.get('description', '无描述')}\n"
            result += f"**索引方式**: {dataset.get('indexing_technique', '未设置')}\n"
            result += f"**权限**: {dataset.get('permission', '未设置')}\n"
            result += f"**创建时间**: {dataset.get('created_at', '')}\n"
            
            return [TextContent(type="text", text=result)]
            
        except Exception as e:
            return [TextContent(
                type="text",
                text=f"❌ 创建知识库失败: {str(e)}"
            )]

    async def _handle_create_document(self, arguments: Dict[str, Any]) -> List[TextContent]:
        """处理创建文档请求"""
        dataset_id = arguments["dataset_id"]
        name = arguments["name"]
        text = arguments["text"]
        indexing_technique = arguments.get("indexing_technique", "high_quality")
        doc_form = arguments.get("doc_form", "text_model")
        doc_language = arguments.get("doc_language", "Chinese")
        
        try:
            document = await self.client.create_document_by_text(
                dataset_id=dataset_id,
                name=name,
                text=text,
                indexing_technique=indexing_technique,
                doc_form=doc_form,
                doc_language=doc_language
            )
            
            doc_info = document.get("document", {})
            batch = document.get("batch", "")
            
            result = f"✅ **文档创建成功**\n\n"
            result += f"**文档名称**: {doc_info.get('name', '未知')}\n"
            result += f"**文档ID**: `{doc_info.get('id', '')}`\n"
            result += f"**批次号**: `{batch}`\n"
            result += f"**索引状态**: {doc_info.get('indexing_status', '未知')}\n"
            result += f"**显示状态**: {doc_info.get('display_status', '未知')}\n"
            result += f"**文档形式**: {doc_info.get('doc_form', '未知')}\n"
            result += f"**字数**: {doc_info.get('word_count', 0)}\n"
            result += f"**创建时间**: {doc_info.get('created_at', '')}\n\n"
            
            if batch:
                result += f"💡 **提示**: 可使用批次号 `{batch}` 查询索引进度\n"
                result += f"   命令: `dify_get_indexing_status` 参数: dataset_id=`{dataset_id}`, batch=`{batch}`"
            
            return [TextContent(type="text", text=result)]
            
        except Exception as e:
            return [TextContent(
                type="text",
                text=(
                    f"❌ 创建文档失败: {str(e)}"
                    + ("\n请先查找或创建合适的数据集后再试。" if "Resource not found" in str(e) else "")
                )
            )]

    async def _handle_get_indexing_status(self, arguments: Dict[str, Any]) -> List[TextContent]:
        """处理获取索引状态请求"""
        dataset_id = arguments["dataset_id"]
        batch = arguments["batch"]
        
        try:
            status_response = await self.client.get_indexing_status(dataset_id, batch)
            status_data = status_response.get("data", [])
            
            if not status_data:
                return [TextContent(
                    type="text",
                    text=f"📄 未找到批次 `{batch}` 的索引状态"
                )]
            
            result = f"📊 **文档索引状态 (批次: {batch})**\n\n"
            
            for i, doc_status in enumerate(status_data, 1):
                doc_id = doc_status.get("id", "未知")
                indexing_status = doc_status.get("indexing_status", "未知")
                completed_segments = doc_status.get("completed_segments", 0)
                total_segments = doc_status.get("total_segments", 0)
                error = doc_status.get("error")
                
                result += f"**文档 {i}** (ID: `{doc_id}`)\n"
                result += f"   - 索引状态: {indexing_status}\n"
                
                if total_segments > 0:
                    progress = (completed_segments / total_segments) * 100
                    result += f"   - 进度: {completed_segments}/{total_segments} ({progress:.1f}%)\n"
                
                if error:
                    result += f"   - ❌ 错误: {error}\n"
                
                # 时间戳
                if doc_status.get("processing_started_at"):
                    result += f"   - 开始时间: {doc_status.get('processing_started_at')}\n"
                if doc_status.get("completed_at"):
                    result += f"   - 完成时间: {doc_status.get('completed_at')}\n"
                
                result += "\n"
            
            return [TextContent(type="text", text=result)]
            
        except Exception as e:
            return [TextContent(
                type="text",
                text=f"❌ 获取索引状态失败: {str(e)}"
            )]

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