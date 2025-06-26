"""
Dify API 客户端
提供与本地 Dify 实例的异步 HTTP 交互
"""

import aiohttp
import asyncio
import logging
from typing import Dict, List, Optional, Any, Union
from urllib.parse import urljoin

logger = logging.getLogger(__name__)


class DifyAPIClient:
    """Dify API 异步客户端"""
    
    def __init__(self, base_url: str = "http://127.0.0.1:5001/v1", api_key: Optional[str] = None):
        self.base_url = base_url.rstrip('/')
        self.api_key = api_key
        self.session: Optional[aiohttp.ClientSession] = None
        
    async def _get_session(self) -> aiohttp.ClientSession:
        """获取或创建 HTTP 会话"""
        if self.session is None or self.session.closed:
            timeout = aiohttp.ClientTimeout(total=30)
            self.session = aiohttp.ClientSession(timeout=timeout)
        return self.session
    
    def _get_headers(self) -> Dict[str, str]:
        """获取请求头"""
        headers = {
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "dify-mcp-bridge/1.0"
        }
        if self.api_key:
            headers["Authorization"] = f"Bearer {self.api_key}"
        return headers
    
    async def _make_request(
        self, 
        method: str, 
        endpoint: str, 
        data: Optional[Dict] = None,
        params: Optional[Dict] = None
    ) -> Dict[str, Any]:
        """发起 HTTP 请求"""
        session = await self._get_session()
        url = urljoin(f"{self.base_url}/", endpoint.lstrip('/'))
        headers = self._get_headers()
        
        try:
            async with session.request(
                method=method,
                url=url,
                json=data,
                params=params,
                headers=headers
            ) as response:
                response_text = await response.text()
                
                if response.status == 200:
                    try:
                        return await response.json()
                    except Exception:
                        # 如果不是JSON，返回文本
                        return {"text": response_text}
                        
                elif response.status == 404:
                    raise ValueError(f"Resource not found: {url}")
                    
                elif response.status == 401:
                    error_msg = "认证失败，请检查API Key是否正确"
                    try:
                        error_data = await response.json()
                        error_msg = error_data.get("message", error_msg)
                    except:
                        pass
                    raise aiohttp.ClientResponseError(
                        request_info=response.request_info,
                        history=response.history,
                        status=response.status,
                        message=error_msg
                    )
                    
                elif response.status == 403:
                    error_msg = "访问被拒绝，请检查API Key权限"
                    try:
                        error_data = await response.json()
                        error_msg = error_data.get("message", error_msg)
                    except:
                        pass
                    raise aiohttp.ClientResponseError(
                        request_info=response.request_info,
                        history=response.history,
                        status=response.status,
                        message=error_msg
                    )
                    
                else:
                    error_text = response_text
                    try:
                        error_data = await response.json()
                        error_text = error_data.get("message", error_text)
                    except:
                        pass
                        
                    raise aiohttp.ClientResponseError(
                        request_info=response.request_info,
                        history=response.history,
                        status=response.status,
                        message=f"API request failed: {error_text}"
                    )
        except aiohttp.ClientError as e:
            logger.error(f"HTTP request failed for {url}: {e}")
            raise
    
    async def get_datasets(self, page: int = 1, limit: int = 20) -> Dict[str, Any]:
        """获取数据集列表
        
        参考官方文档: GET /datasets
        """
        params = {
            "page": page,
            "limit": limit
        }
        return await self._make_request("GET", "/datasets", params=params)
    
    async def get_dataset(self, dataset_id: str) -> Dict[str, Any]:
        """获取单个数据集详情
        
        参考官方文档: GET /datasets/{dataset_id}
        """
        return await self._make_request("GET", f"/datasets/{dataset_id}")
    
    async def search_dataset(
        self, 
        dataset_id: str, 
        query: str,
        retrieval_model: Optional[Dict] = None
    ) -> Dict[str, Any]:
        """在指定数据集中执行检索测试
        
        参考官方文档: POST /datasets/{dataset_id}/retrieve
        """
        # 如果没有提供检索模型，使用默认配置（混合检索+Reranking+BGE-Reranker-Large by Xinference）
        if not retrieval_model:
            retrieval_model = {
                "search_method": "hybrid_search",
                "reranking_enable": True,
                "reranking_model": {
                    "reranking_provider_name": "xinference",
                    "reranking_model_name": "bge-reranker-large"
                },
                "score_threshold_enabled": False
            }
        else:
            # 如果提供了检索模型，添加相关参数
            pass  # 保持原有逻辑
        payload = {
            "query": query,
            "retrieval_model": retrieval_model
        }
        print(payload)
        logging.warning(payload)
        return await self._make_request(
            "POST", 
            f"/datasets/{dataset_id}/retrieve",
            data=payload
        )
    
    async def multi_dataset_search(
        self,
        query: str,
        dataset_ids: Optional[List[str]] = None,
        retrieval_model: Optional[Dict] = None,
        limit_per_dataset: int = 3
    ) -> List[Dict[str, Any]]:
        """在多个数据集中并发搜索"""
        if not dataset_ids:
            # 获取所有可用数据集
            datasets_response = await self.get_datasets()
            dataset_ids = [d["id"] for d in datasets_response.get("data", [])]
        
        # 限制并发数避免过载
        semaphore = asyncio.Semaphore(5)
        
        async def search_single_dataset(dataset_id: str) -> Dict[str, Any]:
            async with semaphore:
                try:
                    # 传递检索模型参数，支持高级检索选项
                    result = await self.search_dataset(dataset_id, query, retrieval_model)
                    return {
                        "dataset_id": dataset_id,
                        "success": True,
                        "result": result
                    }
                except Exception as e:
                    logger.warning(f"Search failed for dataset {dataset_id}: {e}")
                    return {
                        "dataset_id": dataset_id,
                        "success": False,
                        "error": str(e)
                    }
        
        tasks = [search_single_dataset(did) for did in dataset_ids]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # 过滤成功的结果
        successful_results = []
        for result in results:
            if isinstance(result, dict) and result.get("success"):
                successful_results.append(result)
        
        return successful_results
    
    async def chat_completion(
        self, 
        message: str, 
        conversation_id: Optional[str] = None,
        app_id: Optional[str] = None
    ) -> Dict[str, Any]:
        """发送聊天消息（如果配置了聊天应用）"""
        if not app_id:
            raise ValueError("app_id is required for chat completion")
            
        payload = {
            "inputs": {},
            "query": message,
            "response_mode": "blocking",
            "conversation_id": conversation_id or "",
            "user": "mcp-user"
        }
        
        return await self._make_request(
            "POST",
            f"/chat-messages",
            data=payload
        )
    
    async def get_dataset_documents(
        self,
        dataset_id: str,
        page: int = 1,
        limit: int = 20,
        keyword: Optional[str] = None
    ) -> Dict[str, Any]:
        """获取数据集中的文档列表
        
        参考官方文档: GET /datasets/{dataset_id}/documents
        """
        params = {
            "page": page,
            "limit": limit
        }
        if keyword:
            params["keyword"] = keyword
            
        return await self._make_request(
            "GET",
            f"/datasets/{dataset_id}/documents",
            params=params
        )
    
    async def test_connection(self) -> Dict[str, Any]:
        """测试连接到Dify服务"""
        try:
            # 使用一个简单的API调用来测试连接
            response = await self.get_datasets(limit=1)
            return {
                "success": True,
                "message": "连接成功",
                "data": response
            }
        except Exception as e:
            return {
                "success": False,
                "message": f"连接失败: {str(e)}",
                "error": str(e)
            }
    
    async def close(self):
        """关闭 HTTP 会话"""
        if self.session and not self.session.closed:
            await self.session.close()
    
    async def create_dataset(
        self,
        name: str,
        description: str = "",
        indexing_technique: str = "high_quality",
        permission: str = "only_me",
        embedding_model: Optional[str] = None,
        embedding_model_provider: Optional[str] = None
    ) -> Dict[str, Any]:
        """创建知识库数据集
        
        参考官方文档: POST /datasets
        """
        payload = {
            "name": name,
            "description": description,
            "indexing_technique": indexing_technique,
            "permission": permission
        }
        
        if embedding_model:
            payload["embedding_model"] = embedding_model
        if embedding_model_provider:
            payload["embedding_model_provider"] = embedding_model_provider
            
        return await self._make_request("POST", "/datasets", data=payload)

    async def create_document_by_text(
        self,
        dataset_id: str,
        name: str,
        text: str,
        indexing_technique: str = "high_quality",
        doc_form: str = "text_model",
        doc_language: str = "Chinese",
        process_rule: Optional[Dict] = None
    ) -> Dict[str, Any]:
        """通过文本创建文档
        
        参考官方文档: POST /datasets/{dataset_id}/document/create-by-text
        """
        payload = {
            "name": name,
            "text": text,
            "indexing_technique": indexing_technique,
            "doc_form": doc_form,
            "doc_language": doc_language,
            "process_rule": process_rule or {"mode": "automatic"}
        }
        
        return await self._make_request(
            "POST", 
            f"/datasets/{dataset_id}/document/create-by-text",
            data=payload
        )

    async def get_indexing_status(
        self,
        dataset_id: str,
        batch: str
    ) -> Dict[str, Any]:
        """获取文档索引状态
        
        参考官方文档: GET /datasets/{dataset_id}/documents/{batch}/indexing-status
        """
        return await self._make_request(
            "GET",
            f"/datasets/{dataset_id}/documents/{batch}/indexing-status"
        )
    
    async def __aenter__(self):
        """异步上下文管理器入口"""
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """异步上下文管理器出口"""
        await self.close() 