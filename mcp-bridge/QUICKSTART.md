# Dify MCP Bridge 快速开始指南

## 🚀 5分钟快速启动

### 第一步：安装依赖

```bash
cd mcp-bridge
./install.sh
```

或者手动安装：

```bash
pip install -r requirements.txt
cp env.example .env
```

### 第二步：确保 Dify 服务运行

确保本地 Dify 服务已启动并可访问：
- **前端**: http://localhost:3000  
- **后端 API**: http://127.0.0.1:5001/v1

### 第三步：测试连接

```bash
python test_connection.py
```

如果看到类似输出表示成功：
```
✅ 成功连接！发现 2 个数据集
📚 可用数据集:
  1. UniApp X 开发文档 (15 个文档)  
  2. 技术知识库 (8 个文档)
```

### 第四步：启动 MCP 服务器

```bash
python start_server.py
```

### 第五步：配置 Cursor

在 Cursor 中添加 MCP 配置（参考 `cursor-mcp-config.json`）：

1. 打开 Cursor 设置
2. 找到 MCP 配置选项
3. 添加 `dify-knowledge` 服务器配置
4. 重启 Cursor

### 第六步：在 Cursor 中使用

在 Cursor 中使用 `@dify-knowledge` 前缀调用工具：

```
@dify-knowledge dify_search_knowledge query="UniApp X 状态管理" top_k=5
```

```
@dify-knowledge dify_list_datasets include_details=true
```

## 🔧 故障排除

### 问题：连接失败
- 检查 Dify 服务是否运行在 http://127.0.0.1:5001/v1
- 检查 `.env` 文件中的 `DIFY_API_URL` 配置

### 问题：没有找到数据集
- 确保在 Dify 控制台中已创建并索引了知识库
- 检查数据集的索引状态是否为"完成"

### 问题：搜索无结果
- 确保数据集中有文档内容
- 尝试使用更简单的搜索词
- 检查 Dify 的嵌入模型配置

### 问题：Cursor 无法连接 MCP
- 确保 MCP 服务器路径正确
- 检查 Python 环境和依赖
- 查看 Cursor 的 MCP 日志

## 📊 功能演示

### 示例 1：搜索开发文档
```
@dify-knowledge dify_search_knowledge query="如何创建组件" top_k=3
```

### 示例 2：查看数据集信息  
```
@dify-knowledge dify_get_dataset_info dataset_id="your-dataset-id"
```

### 示例 3：多数据集搜索
```
@dify-knowledge dify_search_knowledge query="配置说明" dataset_ids=["id1", "id2"] top_k=5
```

## 🎯 高级配置

### 自定义搜索参数
- `score_threshold`: 设置相似度阈值过滤结果
- `enable_reranking`: 启用重排序提高结果质量  
- `search_method`: 选择搜索方法（语义搜索/关键词搜索）

### 性能优化
- 调整 `top_k` 参数控制返回结果数量
- 使用 `dataset_id` 参数指定特定数据集提高搜索速度
- 配置合适的 `score_threshold` 过滤低质量结果

## 📝 下一步

- 在 Dify 中添加更多知识库内容
- 配置不同的嵌入模型提高搜索质量
- 创建专用的技术文档数据集
- 集成到具体的开发工作流中 