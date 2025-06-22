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
    "dify-local": {
      "command": "python",
      "args": ["/path/to/dify-mcp-bridge/src/mcp_server.py"],
      "env": {
        "DIFY_API_URL": "http://localhost:5001",
        "DIFY_API_KEY": "your-dify-api-key"
      }
    }
  }
}
```

### 3.2 环境变量配置
```bash
# 在 ~/.bashrc 或 ~/.zshrc 中添加
export DIFY_API_URL="http://localhost:5001"
export DIFY_API_KEY="your-generated-api-key"
export DIFY_MCP_BRIDGE_PATH="/path/to/dify-mcp-bridge"
```

## 阶段四：测试和优化

### 4.1 功能测试
1. **知识库搜索测试**
   - 在 Cursor 中输入：`@dify-local search "UniApp X 状态管理"`
   - 验证能否返回相关文档内容

2. **对话功能测试**
   - 在 Cursor 中输入：`@dify-local chat "如何在 UniApp X 中实现组件通信?"`
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
