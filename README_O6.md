# Dify MCP工具

创建日期：2025年6月23日星期一 10:56:34
最后更新日期：2025年6月23日星期一 10:56:34
作者： 莫南+AI

Dify AI平台的本地部署与MCP协议桥接工具，为Order602项目提供强大的AI对话和知识库管理能力。

## 📋 项目简介

Dify MCP工具是一个完整的AI平台解决方案，包含：

- **Dify AI平台**：开源的大语言模型应用开发平台
- **MCP Bridge服务**：将Dify功能封装为MCP协议服务
- **Docker中间件**：完整的数据库和缓存支持
- **Web管理界面**：直观的AI应用管理工具

### 🌟 主要特性

- ✅ **完整部署**：一键部署Dify平台及所有依赖
- ✅ **MCP集成**：与Cursor IDE无缝集成，支持对话和知识库查询
- ✅ **服务管理**：完善的启动、停止、状态检查机制
- ✅ **数据持久化**：支持本地数据存储和备份
- ✅ **多模型支持**：兼容OpenAI、Claude、本地模型等
- ✅ **知识库管理**：支持文档上传、向量化、检索等功能

## 🔧 前置要求

### 必需软件

- **Python 3.12+**：API服务运行环境
- **Node.js 18+**：Web界面构建环境
- **pnpm 8+**：Node.js包管理器
- **Docker**：容器化中间件服务
- **Git**：版本控制和子模块管理

### 系统要求

- **操作系统**：macOS、Linux、Windows WSL2
- **内存**：建议8GB以上
- **存储**：至少5GB可用空间
- **网络**：需要访问GitHub和Docker Hub

## 🚀 快速开始

### 1. 部署服务

```bash
# 进入项目目录
cd mcp/third-party/dify

# 一键部署（包含所有组件）
./scripts/deploy.sh

# 或者强制重新部署
./scripts/deploy.sh --force
```

### 2. 启动服务

```bash
# 启动所有服务
./scripts/start.sh

# 或者按需启动
./scripts/start.sh --api-only     # 仅启动API服务
./scripts/start.sh --web-only     # 仅启动Web界面
./scripts/start.sh --mcp-only     # 仅启动MCP Bridge
./scripts/start.sh --docker-only  # 仅启动Docker中间件
```

### 3. 验证部署

```bash
# 检查服务状态
./scripts/status.sh

# 详细状态信息
./scripts/status.sh --verbose
```

### 4. 访问服务

- **Dify Web界面**：http://localhost:3000
- **Dify API**：http://localhost:5001
- **MCP Bridge**：http://localhost:8080

## 📖 详细使用指南

### 服务管理命令

```bash
# 部署服务
./scripts/deploy.sh [--force]

# 启动服务
./scripts/start.sh [--background] [--api-only|--web-only|--mcp-only|--docker-only]

# 停止服务
./scripts/stop.sh [--force]

# 清理环境
./scripts/clean.sh [--keep-data|--keep-config|--clean-all]

# 状态检查
./scripts/status.sh [--verbose]

# 运行测试
./scripts/test.sh [--quick|--full]
```

### 配置Cursor IDE集成

部署完成后，MCP配置会自动添加到`.cursor/mcp.json`文件中：

```json
{
  "mcpServers": {
    "dify-bridge": {
      "command": "./mcp/third-party/dify/mcp-bridge/.venv/bin/python",
      "args": ["-m", "dify_integration.server", "--api-url", "http://127.0.0.1:5001/v1"],
      "env": {
        "PYTHONPATH": "./mcp/third-party/dify/mcp-bridge"
      },
      "cwd": "./mcp/third-party/dify/mcp-bridge"
    }
  }
}
```

### MCP功能使用

在Cursor中可以使用以下MCP功能：

1. **知识库搜索**：`search_knowledge(query, dataset_ids?, top_k?)`
2. **对话聊天**：`chat_with_dify(message, conversation_id?)`
3. **数据集列表**：`list_datasets(limit?, page?)`

示例：
```typescript
// 搜索知识库
const results = await mcp.call_tool("search_knowledge", {
    query: "uni-app开发指南",
    top_k: 5
});

// 与AI对话
const response = await mcp.call_tool("chat_with_dify", {
    message: "如何创建一个新的uni-app项目?"
});
```

## ⚙️ 配置说明

### 环境变量

主要环境变量在`project.config`文件中定义：

```bash
# 服务端口
DIFY_API_PORT=5001
DIFY_WEB_PORT=3000
MCP_BRIDGE_PORT=8080

# 数据库连接
DIFY_DATABASE_URL=postgresql://dify:dify@localhost:5432/dify
DIFY_REDIS_URL=redis://localhost:6379/0
DIFY_WEAVIATE_URL=http://localhost:8085

# 安全配置
DIFY_SECRET_KEY=your-secret-key-here
CORS_ALLOWED_ORIGINS=http://localhost:3000
```

### 数据目录

- **主数据目录**：`mcp/data/dify_data/`
- **API存储**：`dify/api/storage/`
- **Docker数据卷**：`docker/volumes/`
- **日志文件**：`logs/`
- **PID文件**：`pids/`

### Docker服务

项目会自动启动以下Docker容器：

- **dify-postgres**：PostgreSQL数据库 (端口5432)
- **dify-redis**：Redis缓存 (端口6379)
- **dify-weaviate**：Weaviate向量数据库 (端口8085)
- **dify-elasticsearch**：Elasticsearch搜索引擎 (端口9200)

## 🔍 故障排除

### 常见问题

#### 1. 端口冲突

```bash
# 检查端口占用
lsof -i :5001
lsof -i :3000
lsof -i :8080

# 修改配置文件中的端口设置
nano project.config
```

#### 2. Docker服务启动失败

```bash
# 检查Docker状态
docker ps -a

# 重启Docker服务
./scripts/stop.sh
./scripts/start.sh --docker-only
```

#### 3. Python虚拟环境问题

```bash
# 重新创建虚拟环境
./scripts/clean.sh --keep-data
./scripts/deploy.sh
```

#### 4. 数据库连接失败

```bash
# 检查PostgreSQL容器
docker logs dify-postgres

# 重置数据库
./scripts/clean.sh --clean-all
./scripts/deploy.sh
```

### 日志查看

```bash
# 查看所有日志
ls -la logs/

# 实时查看API日志
tail -f logs/dify-api.log

# 查看错误日志
grep -i error logs/*.log
```

### 性能优化

#### 内存优化

```bash
# 调整Docker资源限制
# 编辑 docker/docker-compose.yaml
nano docker/docker-compose.yaml
```

#### 数据库优化

```bash
# PostgreSQL性能调优
docker exec -it dify-postgres psql -U dify -d dify
# 在psql中运行优化查询
```

## 🧪 开发指南

### 本地开发

```bash
# 开发模式启动（带热重载）
cd dify/web
npm run dev

cd dify/api
python app.py --debug
```

### MCP Bridge开发

```bash
# 进入MCP Bridge目录
cd mcp-bridge

# 激活虚拟环境
source .venv/bin/activate

# 运行开发服务器
python -m dify_integration.server --debug
```

### 添加新功能

1. **API扩展**：在`mcp-bridge/src/dify_integration/`中添加新的工具
2. **MCP协议**：遵循MCP协议规范实现新功能
3. **测试**：在`tests/`目录中添加相应测试
4. **文档**：更新README和API文档

### 调试技巧

```bash
# 启用详细日志
export DIFY_LOG_LEVEL=DEBUG

# 使用调试器
python -m pdb -m dify_integration.server

# 网络调试
curl -X POST http://localhost:5001/v1/chat-messages \
  -H "Content-Type: application/json" \
  -d '{"inputs": {}, "query": "Hello", "response_mode": "blocking"}'
```

## 🤝 贡献指南

### 代码提交

1. Fork项目到个人仓库
2. 创建功能分支：`git checkout -b feature/new-feature`
3. 提交代码：`git commit -m "Add new feature"`
4. 推送分支：`git push origin feature/new-feature`
5. 创建Pull Request

### 代码规范

- **Python**：遵循PEP 8规范
- **JavaScript**：使用ESLint和Prettier
- **Shell脚本**：遵循ShellCheck建议
- **文档**：使用Markdown格式

### 测试要求

```bash
# Python测试
cd mcp-bridge
python -m pytest tests/

# JavaScript测试
cd dify/web
npm test

# 集成测试
./scripts/test.sh --full
```

## 📄 许可证

本项目基于MIT许可证开源，详见[LICENSE](LICENSE)文件。

## 🔗 相关链接

- [Dify官方文档](https://docs.dify.ai/)
- [MCP协议规范](https://modelcontextprotocol.io/)
- [Order602项目](https://github.com/your-org/order602)
- [问题反馈](https://github.com/your-org/order602/issues)

## 📞 技术支持

- **Issue跟踪**：GitHub Issues
- **讨论区**：GitHub Discussions
- **邮箱支持**：support@order602.com

---

## 更新日志

### v0.1.0 (2025-06-23)

- ✨ 初始版本发布
- 🚀 完整的Dify平台部署
- 🔗 MCP协议桥接实现
- 📊 服务管理脚本完善
- 📖 完整文档和使用指南
