# 脱敏配置服务

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/your-repo/sanitization-config-service)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![React](https://img.shields.io/badge/React-19.1.0-61dafb.svg)](https://reactjs.org/)
[![Node.js](https://img.shields.io/badge/Node.js-22+-green.svg)](https://nodejs.org/)
[![TypeScript](https://img.shields.io/badge/TypeScript-4.9.5-blue.svg)](https://www.typescriptlang.org/)

一个完整的数据脱敏规则管理系统，包含React前端管理界面和Node.js后端API服务，提供完整的脱敏规则管理和配置服务功能。

## ✨ 核心特性

### 🎨 前端管理界面
- **现代化UI** - 简洁、直观的用户界面设计
- **完整CRUD** - 创建、读取、更新、删除脱敏规则
- **批量操作** - 支持批量启用、禁用、删除规则
- **实时搜索** - 快速查找和过滤规则
- **规则验证** - 实时验证规则配置正确性
- **响应式设计** - 适配不同屏幕尺寸

### ⚙️ 后端API服务
- **REST API** - 完整的RESTful API接口
- **数据持久化** - JSON文件存储，支持Docker卷挂载
- **健康检查** - 服务状态监控和健康检查
- **统计指标** - 详细的规则统计和使用指标
- **批量操作** - 支持批量规则管理
- **高可用性** - 容器化部署，易于扩展

### 🔄 智能回退机制
- **自动检测** - 自动检测后端服务可用性
- **无缝切换** - 后端不可用时自动切换到本地存储
- **数据同步** - 后端恢复时自动同步数据
- **用户体验** - 保证服务持续可用

## 🚀 快速开始

### 环境要求

- **Node.js** 22.0.0 或更高版本
- **npm** 10.0.0 或更高版本
- **Docker** (可选，用于容器化部署)

### 快速启动

#### 方式一：全栈启动（推荐）

```bash
# 克隆项目
git clone https://github.com/your-repo/sanitization-config-service.git
cd sanitization-config-service

# 一键启动前端和后端
./start-full-stack.sh
```

启动完成后访问：
- 🎨 **前端管理界面**: http://localhost:3000
- ⚙️ **后端API服务**: http://localhost:3001

#### 方式二：分别启动

1. **启动后端服务**
   ```bash
   ./start-backend.sh
   ```

2. **启动前端服务**
   ```bash
   npm install
   npm start
   ```

#### 方式三：仅前端模式

如果只需要前端界面（使用本地存储）：

```bash
npm install
REACT_APP_USE_BACKEND=false npm start
```

### 构建生产版本

```bash
# 构建生产版本
npm run build

# 本地预览构建结果
npm run serve
```

### Docker 部署

使用 Docker Compose 进行一键部署：

```bash
# 一键启动
docker-compose up -d --build

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f

# 停止服务
docker-compose down
```

**服务访问地址：**
- 🎨 **前端界面**: http://localhost:3000
- ⚙️ **后端API**: http://localhost:3001
- 🔗 **健康检查**: http://localhost:3001/api/health

## 📋 功能概览

### 🎨 前端管理功能
- ✅ **规则管理** - 查看、创建、编辑、删除脱敏规则
- ✅ **批量操作** - 批量启用、禁用、删除规则
- ✅ **实时搜索** - 快速查找和过滤规则
- ✅ **导入导出** - 配置文件的导入和导出功能
- ✅ **规则验证** - 实时验证规则配置正确性
- ✅ **统计面板** - 规则统计和使用情况展示

### ⚙️ 后端API功能
- ✅ **RESTful API** - 完整的规则CRUD操作
- ✅ **配置管理** - 统一的配置获取接口
- ✅ **批量操作** - 批量规则管理API
- ✅ **健康检查** - 服务状态监控
- ✅ **统计指标** - 详细的服务指标
- ✅ **数据持久化** - JSON文件存储

### 🔧 规则类型
- **正则表达式** (regex) - 使用正则表达式匹配内容
- **关键字匹配** (key_keyword) - 根据字段名关键字匹配
- **JSON路径** (jsonpath) - 基于JSON路径匹配
- **组合条件** (combined) - 多条件组合逻辑

### 🎯 脱敏算法
- **掩码处理** (mask) - 使用特定字符掩盖敏感信息
- **哈希处理** (hash) - 使用哈希算法处理敏感数据
- **加密处理** (encrypt) - 使用加密算法保护数据
- **替换处理** (replace) - 替换为指定内容
- **移除处理** (remove) - 完全移除敏感信息

### 📊 严重程度
- 🔴 **关键** (critical) - 最高优先级，如身份证、密码
- 🟠 **高** (high) - 高优先级，如手机号、银行卡
- 🟡 **中等** (medium) - 中等优先级，如邮箱、姓名
- 🟢 **低** (low) - 低优先级，如IP地址、普通文本

### 📋 默认规则
系统预置了常用脱敏规则：
- 📱 **手机号脱敏** - 中国手机号格式匹配
- 📧 **邮箱脱敏** - 邮箱地址格式匹配
- 🆔 **身份证脱敏** - 基于字段名关键字匹配

## 🛠️ 技术栈

### 前端技术
| 技术 | 版本 | 用途 |
|------|------|------|
| React | 19.1.0 | 用户界面框架 |
| TypeScript | 4.9.5 | 类型安全的JavaScript |
| Lucide React | 0.469.0 | 现代化图标库 |
| React Hot Toast | 2.5.2 | 消息提示组件 |
| React Scripts | 5.0.1 | 构建和开发工具 |

### 后端技术
| 技术 | 版本 | 用途 |
|------|------|------|
| Node.js | 22+ | 服务器运行时 |
| Express | 4.18.2 | Web应用框架 |
| fs-extra | 11.2.0 | 文件系统操作 |
| CORS | 2.8.5 | 跨域资源共享 |
| Helmet | 7.1.0 | 安全中间件 |

### 部署技术
| 技术 | 版本 | 用途 |
|------|------|------|
| Docker | latest | 容器化部署 |
| Docker Compose | latest | 多容器编排 |
| Nginx | alpine | 反向代理（可选） |

## 📁 项目结构

```
sanitization-config-service/
├── public/                    # 前端静态资源
├── src/                      # 前端源代码
│   ├── components/          # React组件
│   ├── services/           # API服务层
│   ├── types/             # TypeScript类型定义
│   ├── utils/             # 工具函数
│   ├── styles/            # 样式文件
│   ├── App.tsx           # 主应用组件
│   └── index.tsx         # 应用入口
├── server/               # 后端源代码
│   ├── package.json     # 后端依赖配置
│   ├── index.js         # 后端服务器入口
│   └── Dockerfile       # 后端容器镜像
├── data/                # 数据存储目录
├── logs/                # 日志文件目录
├── build/               # 前端构建输出
├── docker-compose.yml   # 多容器编排配置
├── Dockerfile          # 前端容器镜像
├── start-backend.sh    # 后端启动脚本
├── start-full-stack.sh # 全栈启动脚本
├── API.md             # API文档
├── DEVELOPMENT.md     # 开发文档
├── DEPLOYMENT.md      # 部署指南
├── package.json       # 前端项目配置
└── README.md         # 项目说明
```

## 📚 文档

- 📖 [API文档](API.md) - 后端REST API接口说明
- 🔧 [开发文档](DEVELOPMENT.md) - 开发环境设置和代码结构
- 🚀 [部署指南](DEPLOYMENT.md) - Docker Compose部署说明

## 🎯 使用场景

### 📊 企业应用
- **数据隐私保护** - 保护敏感个人信息
- **合规性要求** - 满足GDPR、CCPA等数据保护法规
- **开发测试** - 测试环境数据脱敏
- **日志安全** - 日志中敏感信息处理
- **数据分析** - 分析用数据脱敏

### 🔧 系统集成
- **Java应用集成** - 通过API获取脱敏规则配置
- **微服务架构** - 作为配置中心提供脱敏规则
- **监控系统** - 通过健康检查和指标监控服务状态
- **CI/CD流水线** - 自动化部署和配置管理
- **多环境支持** - 开发、测试、生产环境规则管理

## 🔒 数据安全

### 🛡️ 安全特性
- **智能回退机制** - 后端不可用时自动切换到本地存储
- **数据持久化** - 后端使用JSON文件存储，支持备份
- **容器安全** - 使用非root用户运行容器服务
- **CORS保护** - 配置跨域访问控制
- **健康监控** - 实时监控服务状态和资源使用

### 🔐 数据保护
- **本地优先** - 前端优先使用本地存储保护数据隐私
- **最小权限** - 后端服务采用最小权限原则
- **数据加密** - 支持敏感数据的多种加密算法
- **审计日志** - 记录关键操作和访问日志

## 🚀 部署选项

### 🐳 Docker Compose 部署（推荐）

最简单的部署方式，一键启动完整的前后端服务：

```bash
# 克隆项目
git clone <repository-url>
cd sanitization-config-service

# 一键部署
docker-compose up -d --build
```

**特性：**
- 🐳 **容器化部署** - 前后端分离的微服务架构
- 🔧 **自动构建** - 自动构建前端和后端镜像
- 📊 **健康检查** - 内置健康检查和服务监控
- 🔄 **数据持久化** - 支持数据卷挂载和备份
- 📝 **日志管理** - 统一的日志收集和管理
- ⚡ **负载均衡** - 可选Nginx反向代理

**访问地址：**
- 🎨 前端管理界面: http://localhost:3000
- ⚙️ 后端API服务: http://localhost:3001

### 🔧 开发部署

适合开发和调试：

```bash
# 全栈开发模式
./start-full-stack.sh

# 或分别启动
./start-backend.sh      # 启动后端
npm start              # 启动前端
```

### 📦 生产部署

建议使用Docker Compose配合反向代理：

```bash
# 启用Nginx代理
docker-compose --profile proxy up -d
```

详细部署说明请参考 [部署指南](DEPLOYMENT.md)

## 🤝 贡献

我们欢迎所有形式的贡献！

1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

## 🆘 支持

如果您遇到问题或有任何疑问：

- 📋 [提交Issue](https://github.com/your-repo/sanitization-config-service/issues)
- 💬 [讨论区](https://github.com/your-repo/sanitization-config-service/discussions)
- 📧 发送邮件至 support@example.com

## 🎉 致谢

感谢所有为这个项目做出贡献的开发者和用户！

---

**享受简洁高效的脱敏规则管理体验！** 🎉

## 🆕 重要更新与修复说明

### 全局脱敏开关持久化机制

- **全局脱敏开关** 现已支持后端数据库持久化，刷新页面后状态保持一致。
- 前端会优先从后端API获取全局开关状态，API不可用时自动回退到本地localStorage。
- 切换全局脱敏后，所有规则操作按钮和批量操作会根据全局状态自动禁用/启用。
- 支持多端一致性，保证配置安全可靠。

#### 相关API
- `POST /api/config/global-switch` 切换全局脱敏开关
- `GET /api/config` 获取全局配置和规则

#### 前端体验
- 关闭全局脱敏后，页面所有规则操作按钮自动禁用，显示“全局脱敏已关闭，规则配置暂不可用”
- 刷新页面后，状态保持一致

### 批量操作与重置功能
- 批量启用/禁用规则、重置为默认配置等功能已修复，支持一键操作和状态同步

### 管理脚本

新增一键服务管理脚本 `manage-services.sh`，支持：

```bash
./manage-services.sh start      # 启动所有服务
./manage-services.sh stop       # 停止所有服务
./manage-services.sh restart    # 重启所有服务
./manage-services.sh status     # 查看服务状态
./manage-services.sh logs       # 查看所有服务日志
./manage-services.sh health     # 检查服务健康状态
./manage-services.sh init-db    # 初始化数据库
./manage-services.sh backup     # 备份数据库
./manage-services.sh restore    # 恢复数据库
./manage-services.sh clean      # 清理所有数据
./manage-services.sh update     # 更新服务镜像
```

详细用法请参考 [FIXES_SUMMARY.md](FIXES_SUMMARY.md)
