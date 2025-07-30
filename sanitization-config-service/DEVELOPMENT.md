# 开发文档

## 项目概述

这是一个基于React的纯前端脱敏规则管理系统，采用现代化的UI设计，数据存储在浏览器本地存储中。

## 技术栈

- **React 18** - 用户界面框架
- **TypeScript** - 类型安全的JavaScript
- **自定义CSS** - 现代化样式设计
- **Lucide React** - 现代化图标库
- **React Hot Toast** - 消息提示组件
- **LocalStorage** - 数据持久化存储

## 项目结构

```
sanitization-config-service/
├── public/                 # 静态资源
│   ├── index.html         # HTML模板
│   ├── favicon.ico        # 网站图标
│   └── manifest.json      # PWA配置
├── src/                   # 源代码
│   ├── components/        # React组件（目前为空，使用单页面应用）
│   ├── services/         # API服务层
│   │   └── api.ts        # 本地存储API实现
│   ├── types/           # TypeScript类型定义
│   │   └── index.ts     # 主要类型定义
│   ├── utils/           # 工具函数
│   ├── App.tsx          # 主应用组件
│   ├── index.tsx        # 应用入口
│   └── index.css        # 全局样式
├── build/               # 构建输出目录
├── package.json         # 项目配置
├── tsconfig.json        # TypeScript配置
└── README.md           # 项目说明
```

## 开发环境设置

### 环境要求

- Node.js 22+
- npm 9+ 或 yarn

### 安装依赖

```bash
npm install
```

### 启动开发服务器

```bash
# 使用启动脚本
./start-frontend.sh

# 或直接使用npm
npm start
```

服务器将在 http://localhost:3000 启动

### 构建生产版本

```bash
npm run build
```

构建文件将输出到 `build/` 目录

## 核心功能

### 1. 数据存储

项目使用浏览器的LocalStorage进行数据持久化：

- `sanitization_rules` - 存储脱敏规则配置
- `sanitization_config` - 存储全局配置
- `sanitization_global_enabled` - 存储全局开关状态

### 2. 默认规则

系统预置了三个默认脱敏规则：

- **手机号脱敏** - 匹配中国手机号格式
- **邮箱脱敏** - 匹配邮箱地址格式
- **身份证脱敏** - 匹配中国身份证号格式

### 3. 规则类型

支持四种规则类型：

- `FIELD_NAME` - 字段名匹配
- `PATTERN` - 正则表达式匹配
- `CONTENT_TYPE` - 内容类型匹配
- `CUSTOM` - 自定义匹配逻辑

### 4. 严重程度

支持四个严重程度级别：

- `CRITICAL` - 关键（红色）
- `HIGH` - 高（橙色）
- `MEDIUM` - 中等（黄色）
- `LOW` - 低（绿色）

## API服务层

### 主要方法

- `getRules()` - 获取所有规则
- `createRule(rule)` - 创建新规则
- `updateRule(id, rule)` - 更新规则
- `deleteRule(id)` - 删除规则
- `toggleRule(id, enabled)` - 切换规则状态
- `batchOperation(ids, operation)` - 批量操作
- `validateRule(rule, testInput)` - 验证规则
- `exportRules()` - 导出配置
- `importRules(config)` - 导入配置
- `toggleGlobalSwitch(enabled)` - 全局开关

### 数据格式

规则数据结构：

```typescript
interface SanitizationRule {
  id: string;
  name: string;
  description: string;
  type: 'FIELD_NAME' | 'PATTERN' | 'CONTENT_TYPE' | 'CUSTOM';
  severity: 'CRITICAL' | 'HIGH' | 'MEDIUM' | 'LOW';
  enabled: boolean;
  fieldNames?: string[];
  pattern?: string;
  maskValue: string;
  createdAt?: string;
  updatedAt?: string;
}
```

## 样式系统

项目使用自定义CSS而非CSS框架，主要特点：

- **响应式设计** - 适配不同屏幕尺寸
- **现代化UI** - 简洁的卡片式设计
- **一致的视觉语言** - 统一的颜色和间距
- **流畅的交互** - 平滑的过渡效果

### 主要样式类

- 布局类：`.flex`, `.items-center`, `.justify-between`
- 间距类：`.space-x-*`, `.space-y-*`, `.p-*`, `.m-*`
- 颜色类：`.bg-*`, `.text-*`
- 圆角类：`.rounded-lg`, `.rounded-full`
- 阴影类：`.shadow-sm`, `.shadow-md`

## 开发指南

### 添加新功能

1. 在 `src/types/index.ts` 中定义相关类型
2. 在 `src/services/api.ts` 中实现API方法
3. 在 `src/App.tsx` 中添加UI组件和逻辑

### 修改样式

1. 在 `src/index.css` 中添加或修改样式类
2. 保持与现有设计语言的一致性
3. 确保响应式兼容性

### 数据迁移

如需修改数据结构：

1. 更新类型定义
2. 在API服务中添加数据迁移逻辑
3. 考虑向后兼容性

## 测试

### 运行测试

```bash
npm test
```

### 测试覆盖率

```bash
npm test -- --coverage
```

## 部署

### 静态部署

构建后可部署到任何静态文件服务器：

- Nginx
- Apache
- GitHub Pages
- Netlify
- Vercel

### 部署步骤

1. 构建项目：`npm run build`
2. 将 `build/` 目录内容上传到服务器
3. 配置服务器支持SPA路由（如需要）

## 故障排除

### 常见问题

1. **数据丢失** - 检查浏览器是否清除了LocalStorage
2. **样式异常** - 清除浏览器缓存并重新加载
3. **功能异常** - 检查浏览器控制台错误信息

### 调试技巧

1. 使用浏览器开发者工具查看LocalStorage
2. 检查网络请求（虽然是纯前端应用）
3. 查看控制台日志和错误信息

## 贡献指南

1. Fork项目
2. 创建功能分支
3. 提交更改
4. 创建Pull Request

## 许可证

MIT License
