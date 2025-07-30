# 问题修复总结

## 修复的问题

### 1. 页面操作的状态没有同步到数据库里

**问题描述**：
- 用户在UI上的操作（启用/禁用规则、删除规则、全局开关等）只更新了前端状态，没有同步到后端数据库
- 导致页面刷新后状态丢失

**修复方案**：
- 修改了所有状态变更操作的执行顺序：先调用API同步到数据库，再更新UI状态
- 保留了localStorage作为备份机制，确保在API调用失败时仍能保持状态
- 涉及的操作包括：
  - `toggleRule()` - 切换规则启用状态
  - `deleteRule()` - 删除规则
  - `toggleGlobalSwitch()` - 全局开关
  - `handleSaveRule()` - 创建/编辑规则
  - 批量启用/禁用操作

**修复文件**：
- `src/App.tsx`

### 2. Salt值默认值显示问题

**问题描述**：
- 在规则编辑界面，Salt值输入框显示了默认值 "your-global-salt"
- 应该默认为空，让用户自行输入

**修复方案**：
- 确保Salt值字段初始化为空字符串
- 修改placeholder文本为更友好的提示："留空使用默认Salt值"
- 保持了原有的逻辑：如果用户不输入，系统会使用默认的salt值

**修复文件**：
- `src/components/RuleEditModal.tsx`

### 3. 规则列表居中对齐

**问题描述**：
- 表格中的所有内容都是左对齐，看起来不够整齐
- 需要让大部分列居中对齐，但保持规则名称列左对齐（因为包含描述信息）

**修复方案**：
- 创建了新的CSS类：
  - `.table-header` - 表头居中对齐
  - `.table-header-left` - 表头左对齐（用于规则名称列）
  - `.table-cell` - 表格单元格居中对齐
  - `.table-cell-left` - 表格单元格左对齐（用于规则名称列）
- 调整了表格结构，让规则名称列保持左对齐，其他列居中对齐
- 为操作按钮和开关添加了居中容器

**修复文件**：
- `src/styles/components.css`
- `src/App.tsx`

## 技术细节

### 状态同步策略
```typescript
// 修复前：乐观更新（先更新UI，再调用API）
setConfig(updatedConfig);
await sanitizationApi.toggleRule(ruleId, enabled);

// 修复后：数据库优先（先调用API，再更新UI）
await sanitizationApi.toggleRule(ruleId, enabled);
setConfig(updatedConfig);
localStorage.setItem('backup', JSON.stringify(updatedConfig)); // 备份
```

### CSS样式改进
```css
/* 新增的表格样式类 */
.table-header {
  @apply px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider bg-gray-50;
}

.table-header-left {
  @apply px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider bg-gray-50;
}

.table-cell {
  @apply px-6 py-4 whitespace-nowrap text-sm text-gray-900 text-center;
}

.table-cell-left {
  @apply px-6 py-4 whitespace-nowrap text-sm text-gray-900 text-left;
}
```

## 测试验证

1. **状态同步测试**：
   - 启用/禁用规则后刷新页面，状态应该保持
   - 删除规则后刷新页面，规则应该确实被删除
   - 全局开关切换后刷新页面，状态应该保持

2. **UI显示测试**：
   - Salt值输入框应该默认为空
   - 表格内容应该居中对齐（除了规则名称列）
   - 操作按钮应该居中显示

3. **兼容性测试**：
   - 在API不可用时，应该回退到本地存储模式
   - 显示相应的提示信息（本地模式）

## 影响范围

- **前端**：主要影响用户界面的显示和交互逻辑
- **后端**：无需修改，现有API接口保持不变
- **数据库**：无需修改，现有表结构保持不变
- **兼容性**：保持了向后兼容，支持新旧数据格式

## 部署说明

1. 重新构建前端应用：`npm run build`
2. 重启前端服务（如果需要）
3. 无需重启后端服务
4. 无需数据库迁移

修复完成后，用户体验将得到显著改善，数据一致性问题也得到解决。