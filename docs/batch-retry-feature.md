# 文档管理增强功能

## 功能概述

为Dify文档管理页面新增了两个重要功能：
1. **批量重试文档索引功能** - 解决服务中断导致的文档索引卡死问题
2. **状态过滤功能** - 支持多选状态过滤文档列表

## 1. 批量重试文档索引功能

### 问题描述

当文档索引过程中中断后端服务和Worker服务时，再次打开后不会继续索引，造成文档无法录入资料库。这些文档会一直保持在以下状态：
- 等待中 (waiting)
- 解析中 (parsing)  
- 清理中 (cleaning)
- 分割中 (splitting)
- 索引中 (indexing)
- 已暂停 (paused)
- 错误 (error)

### 解决方案

#### 后端修改

1. **新增API类**: `DocumentBatchRetryAllApi`
   - 路径: `/datasets/<dataset_id>/documents/retry-all`
   - 方法: POST
   - 功能: 批量重试数据集中所有非完成状态的文档

2. **API实现**:
   ```python
   class DocumentBatchRetryAllApi(DocumentResource):
       @setup_required
       @login_required
       @account_initialization_required
       @cloud_edition_billing_rate_limit_check("knowledge")
       def post(self, dataset_id):
           # 查询所有非完成状态的文档
           documents = db.session.query(Document).filter(
               Document.dataset_id == dataset_id,
               Document.tenant_id == current_user.current_tenant_id,
               Document.indexing_status.in_(['waiting', 'parsing', 'cleaning', 'splitting', 'indexing', 'paused', 'error'])
           ).all()
           # 批量重试逻辑

3. **返回数据**:
   ```json
   {
     "result": "success",
     "total_documents": 10,
     "success_count": 8,
     "error_count": 2,
     "message": "已重试 8 个文档，2 个文档重试失败"
   }
   ```

#### 前端修改

1. **新增API服务函数**: `retryAllDocs`
   ```typescript
   export const retryAllDocs: Fetcher<RetryAllDocsResponse, { datasetId: string }> = ({ datasetId }) => {
     return post<RetryAllDocsResponse>(`/datasets/${datasetId}/documents/retry-all`, {})
   }
   ```

2. **UI更新**: 在"元数据"按钮左边添加"恢复索引"按钮
   - 带有刷新图标和loading状态
   - 提供详细的操作反馈

## 2. 状态过滤功能

### 功能描述

在文档列表页面添加状态过滤下拉菜单，支持多选状态来过滤显示不同状态的文档。

### 实现内容

#### 后端修改

1. **文档列表API增强**: 在 `DatasetDocumentListApi.get` 方法中添加状态过滤支持
   ```python
   # 添加状态过滤参数
   status_filter = request.args.getlist("status")  # 获取多个状态值
   
   # 添加状态过滤
   if status_filter:
       # 验证状态值是否有效
       valid_statuses = ['waiting', 'parsing', 'cleaning', 'splitting', 'indexing', 'paused', 'error', 'completed', 'archived']
       filtered_statuses = [status for status in status_filter if status in valid_statuses]
       if filtered_statuses:
           query = query.filter(Document.indexing_status.in_(filtered_statuses))
   ```

#### 前端修改

1. **状态选项定义**:
   ```typescript
   const statusOptions = DocumentIndexingStatusList.map(status => ({
     value: status,
     label: {
       waiting: '等待中',
       parsing: '解析中',
       cleaning: '清理中',
       splitting: '分割中',
       indexing: '索引中',
       paused: '已暂停',
       error: '错误',
       completed: '已完成',
     }[status] || status
   }))
   ```

2. **多选下拉组件**: 在搜索框右侧添加状态过滤器
   - 支持多选状态
   - 显示已选择状态数量
   - 实时过滤文档列表

### 使用方式

1. **批量重试**: 
   - 点击"恢复索引"按钮
   - 系统自动重试所有非完成状态的文档
   - 显示详细的操作结果

2. **状态过滤**:
   - 点击"过滤状态"下拉菜单
   - 勾选需要显示的文档状态
   - 文档列表实时更新显示

### 技术特点

- **批量处理**: 一键重试所有非完成状态的文档
- **智能过滤**: 自动跳过已归档和已完成的文档
- **多状态支持**: 支持所有文档索引状态的过滤
- **详细反馈**: 提供成功/失败统计和详细消息
- **用户体验**: 带有loading状态的响应式UI
- **权限控制**: 完整的用户权限验证

### 修改文件

1. **后端文件**:
   - `mcp/third-party/dify-local/dify/api/controllers/console/datasets/datasets_document.py`

2. **前端文件**:
   - `mcp/third-party/dify-local/dify/web/service/datasets.ts`
   - `mcp/third-party/dify-local/dify/web/models/datasets.ts`
   - `mcp/third-party/dify-local/dify/web/app/components/datasets/documents/index.tsx`

## 使用方法

1. 进入数据集的文档页面
2. 在页面右上角找到"恢复索引"按钮（位于"元数据"按钮左边）
3. 点击按钮执行批量重试
4. 系统会自动重试所有非完成状态的文档
5. 操作完成后会显示重试结果

## 权限要求

- 用户必须是数据集的编辑者（dataset_editor）
- 需要通过数据集权限检查
- 受云版本计费限制检查

## 注意事项

1. 只会重试状态为 `waiting`、`parsing`、`cleaning`、`splitting`、`indexing`、`paused`、`error` 的文档
2. 已归档的文档会被跳过
3. 操作会记录详细的成功和失败统计
4. 重试后会自动刷新文档列表
5. 按钮在操作进行中会显示loading状态并禁用

## 测试建议

1. 创建一些测试文档并人为中断索引过程
2. 验证文档状态是否正确显示为非完成状态
3. 点击"恢复索引"按钮测试批量重试功能
4. 检查重试后的状态变化和提示信息
5. 验证权限控制是否正常工作 