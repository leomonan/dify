# Dify MCP 集成实施方案

## 阶段一：Dify 本地源码部署

### 1.1 环境准备
```bash
# 1. 克隆 Dify 仓库
git clone https://github.com/langgenius/dify.git
cd dify

# 2. 启动中间件服务
cd docker
cp middleware.env.example middleware.env
docker compose -f docker-compose.middleware.yaml up -d

# 3. 设置 Python 环境
pyenv install 3.12
pyenv global 3.12

# 4. 后端服务配置
cd ../api
cp .env.example .env
# 生成密钥
awk -v key="$(openssl rand -base64 42)" '/^SECRET_KEY=/ {sub(/=.*/, "=" key)} 1' .env > temp_env && mv temp_env .env

# 5. 安装依赖
uv sync
# macOS 需要安装 libmagic
brew install libmagic

# 6. 数据库迁移
uv run flask db upgrade

# 7. 启动后端服务
uv run flask run --host 0.0.0.0 --port=5001 --debug 

# 8. 启动 Worker 服务
uv run celery -A app.celery worker -P gevent -c 1 --loglevel DEBUG -Q dataset,generation,mail,ops_trace

# 9. 前端服务配置
cd ../web
npm i -g pnpm
pnpm install --frozen-lockfile

# 10. 配置前端环境变量
cp .env.example .env.local
# 编辑 .env.local，设置 API 端点

# 11. 构建并启动前端
pnpm build
pnpm start

# 12. 启动 xinference
  xinference-local
```

## 阶段二：MCP Bridge Server 开发

### 2.1 项目结构
```
mcp-bridge/
├── src/
│   ├── mcp_server.py          # MCP 服务器主入口
│   ├── protocol/
│   │   ├── __init__.py
│   │   ├── handlers.py        # MCP 协议处理器
│   │   └── types.py           # MCP 类型定义
│   ├── dify_integration/
│   │   ├── __init__.py
│   │   ├── api_client.py      # Dify API 客户端
│   │   ├── knowledge_manager.py  # 知识库管理
│   │   └── chat_manager.py    # 对话管理
│   └── tools/
│       ├── __init__.py
│       ├── search_tool.py     # 搜索工具
│       └── chat_tool.py       # 对话工具
├── requirements.txt
├── setup.py
└── README.md
```

### 2.2 核心代码实现

#### MCP 服务器主入口 (src/mcp_server.py)


#### Dify API 客户端 (src/dify_integration/api_client.py)


## 阶段三：Cursor 集成配置

### 3.1 MCP 配置文件
创建 `~/.cursor/mcp-settings.json`:
```json
{
  "mcpServers": {
    "dify-knowledge": {
      "command": "python",
      "args": ["/path/to/dify-mcp-bridge/src/mcp_server.py"],
      "env": {
        "DIFY_API_URL": "http://127.0.0.1:5001/v1",
        "DIFY_API_KEY": "your-dify-api-key"
      }
    }
  }
}
```

### 3.2 环境变量配置
```bash
# 在 ~/.bashrc 或 ~/.zshrc 中添加
export DIFY_API_URL="http://127.0.0.1:5001/v1"
export DIFY_API_KEY="your-generated-api-key"
export DIFY_MCP_BRIDGE_PATH="/path/to/dify-mcp-bridge"
```

## 阶段四：测试和优化

### 4.1 功能测试
1. **知识库搜索测试**
   - 在 Cursor 中输入：`@dify-knowledge search "UniApp X 状态管理"`
   - 验证能否返回相关文档内容

2. **对话功能测试**
   - 在 Cursor 中输入：`@dify-knowledge chat "如何在 UniApp X 中实现组件通信?"`
   - 验证能否获得智能回答

3. **资源列表测试**
   - 验证 Cursor 能否正确显示 Dify 中的所有数据集

### 4.2 性能优化
1. **连接池优化**：使用 aiohttp 连接池减少连接开销
2. **缓存机制**：对频繁查询的结果进行缓存
3. **异步处理**：确保所有 API 调用都是异步的

### 4.3 错误处理
```python
async def safe_api_call(self, func, *args, **kwargs):
    """安全的 API 调用包装器"""
    try:
        return await func(*args, **kwargs)
    except aiohttp.ClientError as e:
        logger.error(f"Dify API 连接错误: {e}")
        return {"error": "无法连接到 Dify 服务"}
    except Exception as e:
        logger.error(f"未知错误: {e}")
        return {"error": "处理请求时发生错误"}
```

## 预期效果

1. **无缝集成**：在 Cursor 中直接访问本地 Dify 知识库
2. **智能搜索**：利用 Dify 的语义搜索能力快速找到相关代码和文档
3. **上下文感知**：结合当前代码上下文提供精准建议
4. **实时同步**：Dify 知识库更新后立即在 Cursor 中可用

## 扩展功能

1. **代码生成**：基于知识库内容生成代码片段
2. **智能问答**：回答项目相关的技术问题
3. **文档更新**：自动同步项目文档到 Dify 知识库
4. **工作流集成**：利用 Dify Workflow 执行复杂的代码分析任务

## 数据存储位置

### Dify 知识库数据存储

Dify 的知识库数据文件默认存储在以下位置：

#### 本地存储配置
- **配置文件**：`api/.env` 或 `api/.env.example`
- **存储类型**：`STORAGE_TYPE=opendal`（默认）
- **存储根目录**：`OPENDAL_FS_ROOT=storage`

#### 实际存储路径
```bash
# 知识库文档文件存储路径
{dify-project}/api/storage/upload_files/

# 目录结构示例
storage/
├── privkeys/           # 私钥文件
└── upload_files/       # 上传的知识库文档
    └── {dataset-id}/   # 按数据集ID分组
        ├── {file-uuid}.html
        ├── {file-uuid}.pdf
        └── {file-uuid}.txt
```

#### 存储说明
1. **文档文件**：所有上传到知识库的文档（HTML、PDF、TXT等）都存储在 `storage/upload_files/` 目录下
2. **按数据集分组**：每个知识库数据集有独立的子目录，目录名为数据集UUID
3. **文件重命名**：上传的文件会被重命名为UUID格式，保持原始扩展名
4. **数据库元数据**：文档的元数据信息存储在PostgreSQL数据库中
5. **向量数据**：如果配置了向量存储（如Weaviate、Qdrant等），向量数据存储在对应的向量数据库中

#### 修改存储位置
如需修改存储位置，可在 `.env` 文件中配置：
```bash
# 修改本地存储根目录
OPENDAL_FS_ROOT=/custom/storage/path

# 或使用其他存储类型（S3、阿里云OSS等）
STORAGE_TYPE=s3
S3_ENDPOINT=https://your-bucket.s3.amazonaws.com
S3_ACCESS_KEY=your-access-key
S3_SECRET_KEY=your-secret-key
S3_BUCKET_NAME=your-bucket-name
```

#### 备份建议
- **完整备份**：备份整个 `storage/` 目录 + PostgreSQL数据库
- **增量备份**：定期备份新增的文档文件
- **向量数据**：如使用外部向量数据库，需同时备份向量数据

#### MCP集成考虑
在MCP Bridge中访问知识库时，需要：
1. 通过Dify API获取文档内容（推荐）
2. 或直接读取存储文件（需要解析数据库获取文件映射关系） 
