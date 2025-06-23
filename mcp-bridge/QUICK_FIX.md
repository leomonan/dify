# 🚨 API Key 问题快速修复

遇到 `401 Unauthorized` 或 `Invalid token` 错误？这里是最快的解决方案：

## 1️⃣ 获取正确的 API Key

1. **打开 Dify 管理后台**
   - 浏览器访问：`http://127.0.0.1:5001/v1`
   - 登录到 Dify

2. **进入知识库页面**
   - 点击左侧菜单的「知识库」

3. **获取 API Key**
   - 点击右上角的「API」按钮
   - 复制显示的 API Key
   - **重要**：API Key 应该以 `dataset-` 开头

## 2️⃣ 配置 API Key

### 方法 A：使用配置助手
```bash
python setup_env.py
```

### 方法 B：手动编辑
```bash
# 编辑 .env 文件
nano .env

# 添加/修改这一行：
DIFY_API_KEY=dataset-你的实际API-Key-这里
```

## 3️⃣ 测试连接
```bash
python test_connection.py
```

## ✅ 成功标志
看到这样的输出表示成功：
```
✅ 成功连接！发现 X 个数据集
📚 可用数据集:
  1. 知识库名称 (X 个文档) - ID: abc123...
```

## ❌ 仍然失败？

1. **检查 Dify 是否在运行**
   ```bash
   curl http://127.0.0.1:5001/v1
   ```

2. **确认 API Key 格式**
   - 必须以 `dataset-` 开头
   - 长度通常在 40-60 个字符
   - 不包含空格或特殊字符

3. **重新生成 API Key**
   - 在 Dify 控制台删除旧的 API Key
   - 创建新的 API Key
   - 重新配置

## 📞 还需要帮助？
查看完整的 [故障排除指南](./TROUBLESHOOTING.md) 