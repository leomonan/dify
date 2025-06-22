# Dify MCP Bridge

基于 FastMCP 框架的 MCP 服务器，提供 Cursor IDE 与本地 Dify 实例的知识库检索集成。

## 功能特性

- 🔍 **知识库搜索**: 在 Dify 数据集中执行语义搜索
- 📚 **多数据集支持**: 同时搜索多个知识库并合并结果
- ⚡ **高性能**: 基于异步 HTTP 客户端和 uvloop
- 🛠️ **易于配置**: 通过环境变量简单配置
- 🎯 **Cursor 集成**: 完全兼容 Cursor IDE 的 MCP 协议

## 安装依赖

```bash
cd mcp-bridge
pip install -r requirements.txt
```

## 配置

### 方法 A：使用配置助手（推荐）
```bash
python setup_env.py
```

### 方法 B：手动配置
1. 复制环境变量配置文件：
```bash
cp env.example .env
```

2. 编辑 `.env` 文件，配置 Dify API 地址：
```bash
DIFY_API_URL=http://localhost:5001
DIFY_API_KEY=your-api-key-here
```

### 测试连接
```bash
python test_connection.py
```

## 运行服务器

```bash
python src/mcp_server.py
```

## 在 Cursor 中配置

在 Cursor 的 MCP 设置中添加以下配置：

```json
{
  "mcpServers": {
    "dify-knowledge": {
      "command": "python",
      "args": ["/path/to/mcp-bridge/src/mcp_server.py"],
      "env": {
        "DIFY_API_URL": "http://localhost:5001"
      }
    }
  }
}
```

## 可用工具

### `dify_list_datasets`
列出所有可用的知识库数据集。

**参数**:
- `page` (int): 页码，默认 1
- `limit` (int): 每页数量，默认 20
- `include_details` (bool): 是否包含详细信息，默认 false

### `dify_search_knowledge`
在知识库中搜索相关内容。

**参数**:
- `query` (string): 搜索查询文本 **(必需)**
- `dataset_id` (string): 单个数据集 ID
- `dataset_ids` (list): 多个数据集 ID 列表
- `top_k` (int): 返回结果数量，默认 5
- `score_threshold` (float): 相似度阈值，默认 0.0
- `enable_reranking` (bool): 是否启用重排序，默认 false
- `search_method` (string): 搜索方法，默认 "semantic_search"

### `dify_get_dataset_info`
获取指定数据集的详细信息。

**参数**:
- `dataset_id` (string): 数据集 ID **(必需)**

### `dify_search_documents`
搜索数据集中的文档。

**参数**:
- `dataset_id` (string): 数据集 ID **(必需)**
- `keyword` (string): 搜索关键词
- `page` (int): 页码，默认 1
- `limit` (int): 每页数量，默认 10

## 使用示例

在 Cursor 中使用 MCP 工具：

```
@dify-knowledge dify_search_knowledge query="UniApp X 状态管理" top_k=5
```

```
@dify-knowledge dify_list_datasets include_details=true
```

## 故障排除

常见问题的详细解决方案请查看 [故障排除指南](./TROUBLESHOOTING.md)。

快速检查：
1. **连接失败**: 确保 Dify 服务器在指定地址运行
2. **API 认证错误**: 检查 `.env` 文件中的 `DIFY_API_KEY` 配置
3. **依赖错误**: 运行 `./install.sh` 确保所有依赖已正确安装
4. **测试连接**: 运行 `python test_connection.py` 进行诊断

## 开发

项目结构：
```
mcp-bridge/
├── src/
│   ├── mcp_server.py          # MCP 服务器主入口
│   └── dify_integration/
│       ├── __init__.py
│       └── api_client.py      # Dify API 客户端
├── requirements.txt
├── env.example
└── README.md
``` 