# Dify MCP Bridge 故障排除指南

## 🔐 API Key 认证问题

### 错误信息：`401 Unauthorized` 或 `Invalid token`

这是最常见的问题，通常由以下原因引起：

#### 1. API Key 未配置或为空
**解决方法：**
```bash
# 1. 运行环境配置助手
python setup_env.py

# 2. 或手动创建 .env 文件
cp env.example .env
# 然后编辑 .env 文件，填写正确的 DIFY_API_KEY
```

#### 2. API Key 格式不正确
**获取正确的 API Key：**
1. 登录 Dify 管理后台
2. 进入「知识库」页面
3. 点击右上角的「API」按钮
4. 复制显示的 API Key
5. API Key 通常以 `dataset-` 开头

**示例：**
```
DIFY_API_KEY=dataset-aBc123DeF456GhI789JkL012MnO345
```

#### 3. API Key 权限不足
确保使用的 API Key 有访问知识库的权限。

#### 4. API Key 已过期
检查 Dify 控制台，重新生成 API Key。

## 🌐 网络连接问题

### 错误信息：连接超时或拒绝连接

#### 1. 检查 Dify 服务状态
```bash
# 检查 Dify 是否正在运行
curl http://127.0.0.1:5001/v1/health

# 如果使用 Docker
docker ps | grep dify
```

#### 2. 检查端口和 URL
确保 `.env` 文件中的 URL 正确：
```
DIFY_API_URL=http://127.0.0.1:5001/v1
```

如果 Dify 运行在不同端口或服务器上，相应修改。

## 🔍 API 端点问题

### 错误信息：`404 Not Found`

可能是 Dify 版本不兼容，确保使用支持以下 API 的 Dify 版本：
- `GET /console/api/datasets`
- `GET /console/api/datasets/{id}`
- `POST /console/api/datasets/{id}/retrieve`

## 🧪 测试步骤

### 1. 环境配置测试
```bash
python setup_env.py
```

### 2. 连接测试
```bash
python test_connection.py
```

### 3. 逐步诊断
如果测试失败，检查输出中的详细错误信息：
- 🔐 认证相关 → 检查 API Key
- 🌐 网络相关 → 检查 Dify 服务和 URL
- 🔗 API 相关 → 检查 Dify 版本

## 📝 常见配置问题

### 1. .env 文件位置错误
确保 `.env` 文件在 `mcp-bridge/` 目录下：
```
mcp-bridge/
├── .env          ← 应该在这里
├── env.example
├── test_connection.py
└── ...
```

### 2. 环境变量未加载
如果手动编辑 `.env` 文件，确保格式正确：
```bash
# 正确格式（等号前后无空格）
DIFY_API_KEY=your-api-key-here

# 错误格式
DIFY_API_KEY = your-api-key-here  # 有空格
DIFY_API_KEY="your-api-key-here"  # 有引号（通常不需要）
```

## 🚀 成功配置检查清单

- [ ] Dify 服务正在运行
- [ ] `.env` 文件存在于正确位置
- [ ] `DIFY_API_KEY` 已正确设置
- [ ] `DIFY_API_URL` 指向正确的服务地址
- [ ] API Key 有正确的权限
- [ ] `python test_connection.py` 运行成功

## 💡 更多帮助

如果问题仍然存在：

1. **检查 Dify 日志：** 查看 Dify 服务器的日志文件
2. **网络诊断：** 使用 `curl` 或 `ping` 测试网络连接
3. **版本兼容性：** 确认 Dify 版本支持所需的 API 端点

**调试模式运行：**
```bash
LOG_LEVEL=DEBUG python test_connection.py
``` 