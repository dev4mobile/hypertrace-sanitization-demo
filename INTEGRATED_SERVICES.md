# 整合服务架构说明

本文档说明了如何将脱敏配置服务整合到主项目的 Docker Compose 环境中。

## 服务架构

整合后的系统包含以下服务：

### 核心服务
- **Hypertrace Demo App** (端口 8080) - 主应用程序
- **Jaeger** (端口 16686) - 分布式追踪系统
- **Kafka** (端口 9092) - 消息代理
- **Zookeeper** (端口 2181) - Kafka 协调服务
- **PostgreSQL** (端口 5432) - 主数据库

### 脱敏配置服务
- **Sanitization Frontend** (端口 3000) - 脱敏配置管理界面
- **Sanitization Backend** (端口 3001) - 脱敏配置 API 服务
- **Sanitization PostgreSQL** (端口 55432) - 脱敏配置专用数据库

## 网络配置

所有服务都运行在同一个 Docker 网络 `hypertrace-network` 中，服务间可以通过服务名进行通信：

- 主应用通过 `http://sanitization-backend:3001` 访问脱敏配置 API
- 脱敏后端通过 `sanitization-postgres:5432` 访问数据库
- 脱敏前端通过 `http://localhost:3001` 访问后端 API（浏览器访问）

## 端口映射

| 服务 | 内部端口 | 外部端口 | 说明 |
|------|----------|----------|------|
| Hypertrace Demo | 8080 | 8080 | 主应用 |
| Jaeger UI | 16686 | 16686 | 追踪界面 |
| Kafka | 29092 | 9092 | 消息代理 |
| Zookeeper | 2181 | 2181 | 协调服务 |
| PostgreSQL (主) | 5432 | 5432 | 主数据库 |
| Sanitization Frontend | 8080 | 3000 | 脱敏管理界面 |
| Sanitization Backend | 3001 | 3001 | 脱敏 API |
| Sanitization PostgreSQL | 5432 | 55432 | 脱敏数据库 |

## 数据卷

- `kafka-data` - Kafka 数据持久化
- `postgres-data` - 主数据库数据持久化
- `sanitization-postgres-data` - 脱敏配置数据库数据持久化

## 启动和管理

### 快速启动
```bash
# 启动所有服务
./start-integrated-services.sh
```

### 管理命令
```bash
# 查看帮助
./manage-integrated-services.sh help

# 启动服务
./manage-integrated-services.sh start

# 停止服务
./manage-integrated-services.sh stop

# 查看状态
./manage-integrated-services.sh status

# 查看日志
./manage-integrated-services.sh logs

# 检查健康状态
./manage-integrated-services.sh health
```

## 服务依赖关系

```
hypertrace-demo-app
├── postgres (主数据库)
├── kafka
├── jaeger
└── sanitization-backend (脱敏配置)

sanitization-backend
└── sanitization-postgres (脱敏数据库)

sanitization-frontend
└── sanitization-backend

kafka
└── zookeeper
```

## 配置说明

### 主应用配置
主应用的脱敏配置端点已更新为：
```
HT_SANITIZATION_CONFIG_ENDPOINT=http://sanitization-backend:3001/api/sanitization/rules
```

### 数据库配置
- 主数据库：`postgres:5432/hypertrace`
- 脱敏数据库：`sanitization-postgres:5432/sanitization_config`

### 环境变量
所有服务的环境变量都已在 `docker-compose.yml` 中配置，包括：
- 数据库连接信息
- 服务间通信地址
- 资源限制配置

## 健康检查

所有关键服务都配置了健康检查：
- 数据库服务：检查数据库连接
- 后端服务：检查 HTTP 健康端点
- 前端服务：检查 Nginx 服务状态

## 资源限制

为了优化资源使用，各服务都配置了资源限制：
- 脱敏数据库：最大 512MB 内存，0.5 CPU
- 脱敏后端：最大 256MB 内存，0.3 CPU
- 脱敏前端：最大 512MB 内存，0.5 CPU

## 故障排除

### 常见问题

1. **端口冲突**
   - 确保端口 3000, 3001, 55432 未被其他服务占用
   - 可以修改 docker-compose.yml 中的端口映射

2. **数据库连接失败**
   - 检查数据库服务是否正常启动
   - 查看数据库日志：`docker-compose logs sanitization-postgres`

3. **服务启动缓慢**
   - 首次启动需要下载镜像和初始化数据库
   - 等待所有健康检查通过

### 日志查看
```bash
# 查看所有服务日志
docker-compose logs -f

# 查看特定服务日志
docker-compose logs -f sanitization-backend

# 查看脱敏相关服务日志
./manage-integrated-services.sh logs-san
```

## 开发和调试

### 本地开发
如果需要在本地开发脱敏配置服务：
1. 停止对应的 Docker 服务
2. 在本地启动开发服务器
3. 更新主应用的配置端点

### 数据库访问
```bash
# 连接主数据库
psql -h localhost -p 5432 -U postgres -d hypertrace

# 连接脱敏配置数据库
psql -h localhost -p 55432 -U sanitization_user -d sanitization_config
```

## 安全考虑

1. **数据库密码**：生产环境中应使用更强的密码
2. **网络隔离**：考虑使用多个 Docker 网络进行服务隔离
3. **SSL/TLS**：生产环境中应启用 HTTPS
4. **访问控制**：配置适当的防火墙规则

## 扩展和定制

### 添加新服务
1. 在 `docker-compose.yml` 中添加服务定义
2. 确保网络配置正确
3. 更新管理脚本中的服务列表

### 修改配置
1. 编辑 `docker-compose.yml`
2. 重新启动相关服务
3. 验证配置更改是否生效