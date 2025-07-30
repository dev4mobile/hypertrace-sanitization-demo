# 环境变量配置文档

本文档描述了脱敏配置服务所需的环境变量配置。

## 应用配置

```bash
# 应用运行环境
NODE_ENV=development  # 可选: development, production, test

# 服务端口
PORT=3001  # 默认: 3001
```

## 数据库配置

```bash
# PostgreSQL 数据库连接配置
DB_HOST=localhost                      # 数据库主机地址
DB_PORT=55432                          # 数据库端口
DB_NAME=sanitization_config           # 数据库名称
DB_USER=sanitization_user             # 数据库用户名
DB_PASSWORD=sanitization_pass_2024!   # 数据库密码
DB_SSL=false                          # 是否启用 SSL 连接
```

## 数据库连接池配置

```bash
# 连接池配置
DB_POOL_MAX=10        # 最大连接数
DB_POOL_MIN=2         # 最小连接数
DB_IDLE_TIMEOUT=30000 # 空闲超时时间(毫秒)
DB_CONNECTION_TIMEOUT=5000  # 连接超时时间(毫秒)
```

## 前端配置

```bash
# 前端应用配置 (仅用于开发环境)
REACT_APP_API_URL=http://localhost:3001  # 后端 API 地址
REACT_APP_USE_BACKEND=true                # 是否使用后端服务
REACT_APP_VERSION=1.0.0                   # 应用版本
```

## 安全配置

```bash
# CORS 配置
FRONTEND_URL=http://localhost:3000,http://localhost:3001  # 允许的前端域名
```

## 日志配置

```bash
# 日志配置
LOG_LEVEL=info       # 日志级别: error, warn, info, debug
LOG_FORMAT=combined  # 日志格式
```

## Docker 部署

在使用 Docker Compose 部署时，可以在 `docker-compose.yml` 文件的 `environment` 部分设置这些变量，或者创建 `.env` 文件：

```bash
# .env 文件示例
NODE_ENV=production
PORT=3001

# 数据库配置
DB_HOST=sanitization-postgres
DB_PORT=5432
DB_NAME=sanitization_config
DB_USER=sanitization_user
DB_PASSWORD=sanitization_pass_2024!
DB_SSL=false

# 连接池配置
DB_POOL_MAX=10
DB_POOL_MIN=2
DB_IDLE_TIMEOUT=30000
DB_CONNECTION_TIMEOUT=5000

# 安全配置
FRONTEND_URL=http://localhost:3000
```

## 本地开发

在本地开发时，可以创建 `.env` 文件或直接在启动命令中设置环境变量：

```bash
# 使用 .env 文件
cp ENV_CONFIG.md.example .env
# 然后编辑 .env 文件

# 或者直接在命令中设置
DB_HOST=localhost DB_PORT=5432 npm run dev
```

## 数据库初始化

首次启动服务前，需要初始化数据库：

```bash
# 初始化数据库表结构
npm run db:init

# 或者使用 Docker
docker-compose exec sanitization-backend npm run db:init
```
