# Hypertrace Demo 部署文档

## 概述

本文档介绍如何部署 Hypertrace Demo 项目，支持在线和离线环境部署。

## 系统要求

### 硬件要求
- CPU: 2核心以上
- 内存: 4GB 以上
- 磁盘空间: 10GB 以上

### 软件要求
- 操作系统: Linux/macOS/Windows
- Docker: 20.10+ 
- Docker Compose: 2.0+

### 端口要求
确保以下端口未被占用：
- `10020` - Spring Boot 应用
- `16686` - Jaeger UI
- `9092` - Kafka (KRaft 模式)
- `3000` - 脱敏配置前端
- `3001` - 脱敏配置后端API

## 部署步骤

### 1. 获取部署包

#### 方式一：从源码打包
```bash
# 克隆项目
git clone <repository-url>
cd hypertrace-demo

# 运行打包脚本
chmod +x package.sh
./package.sh
```

#### 方式二：使用预构建包
下载预构建的 `hypertrace-demo-1.0.0.tar.gz` 文件。

### 2. 解压部署包

```bash
# 解压文件
tar -xzf hypertrace-demo-1.0.0.tar.gz

# 进入项目目录
cd hypertrace-demo-1.0.0
```

### 3. 验证文件完整性（可选）

```bash
# 检查校验和
sha256sum -c hypertrace-demo-1.0.0.tar.gz.sha256
```

### 4. 检查系统环境

```bash
# 运行系统检查
./install.sh --check
```

### 5. 部署应用

#### 标准部署
```bash
# 一键安装
./install.sh
```

#### 清理旧数据后部署
```bash
# 清理旧数据并安装
./install.sh --clean
```

### 6. 验证部署

部署完成后，访问以下地址验证服务：

- **应用主页**: http://localhost:10020
- **Jaeger 追踪**: http://localhost:16686
- **脱敏配置管理**: http://localhost:3000

## 离线部署说明

本部署包支持完全离线部署，包含以下内容：

**预打包的 Docker 镜像：**
- `jaegertracing/all-in-one:latest` - 分布式追踪
- `confluentinc/cp-kafka:7.6.0` - Kafka 消息队列 (KRaft 模式)
- `postgres:16-alpine` - PostgreSQL 数据库
- `hypertrace-demo-app:latest` - 应用镜像
- `sanitization-backend:latest` - 脱敏配置后端服务
- `sanitization-frontend:latest` - 脱敏配置前端界面

**配置文件：**
- `docker-compose.yml` - 服务编排配置
- `hypertrace-config*.yaml` - Hypertrace 配置文件
- `agents/` - Hypertrace Agent 文件
- `sanitization-config-service/` - 脱敏配置服务

**部署脚本：**
- `install.sh` - 一键安装脚本
- `uninstall.sh` - 卸载脚本
- `load-images.sh` - 镜像加载脚本

### 手动加载镜像

如果需要单独加载 Docker 镜像：

```bash
# 加载所有镜像
./load-images.sh

# 查看已加载的镜像
docker images | grep -E "(jaegertracing|confluentinc|postgres|hypertrace-demo-app)"
```

## 测试应用

### 基本功能测试

```bash
# 创建用户
curl -X POST http://localhost:10020/api/users \
     -H 'Content-Type: application/json' \
     -d '{"name":"测试用户","email":"test@example.com"}'

# 查询用户
curl http://localhost:10020/api/users

# 触发 Kafka 通知
curl -X POST http://localhost:10020/api/users/1/notify
```

### 追踪验证

1. 访问 Jaeger UI: http://localhost:16686
2. 选择服务: `hypertrace-demo-app`
3. 点击 "Find Traces" 查看追踪数据

### 脱敏配置测试

1. 访问管理界面: http://localhost:3000
2. 配置脱敏规则
3. 测试 API 响应数据脱敏效果

## 管理命令

### 查看服务状态
```bash
docker-compose ps
```

### 查看日志
```bash
# 查看所有服务日志
docker-compose logs

# 查看特定服务日志
docker-compose logs -f hypertrace-demo-app
docker-compose logs -f jaeger
docker-compose logs -f kafka
```

### 重启服务
```bash
# 重启所有服务
docker-compose restart

# 重启特定服务
docker-compose restart hypertrace-demo-app
```

### 停止服务
```bash
# 停止服务（保留数据）
docker-compose stop

# 停止并删除容器（保留数据卷）
docker-compose down

# 完全清理（删除数据卷）
docker-compose down -v
```

## 卸载

### 完全卸载
```bash
# 运行卸载脚本
./uninstall.sh
```

### 手动卸载
```bash
# 停止并删除所有容器和数据
docker-compose down -v --remove-orphans

# 删除相关镜像
docker images | grep hypertrace-demo | awk '{print $3}' | xargs docker rmi -f

# 清理未使用的资源
docker system prune -f
```

## 故障排除

### 常见问题

#### 1. 端口被占用
```bash
# 检查端口占用
lsof -i :10020
lsof -i :16686

# 停止占用端口的进程或修改 docker-compose.yml 中的端口映射
```

#### 2. Docker 服务未启动
```bash
# 启动 Docker 服务
sudo systemctl start docker

# 或在 macOS 上启动 Docker Desktop
```

#### 3. 内存不足
```bash
# 检查系统资源
free -h
docker system df

# 清理未使用的镜像和容器
docker system prune -a
```

#### 4. 镜像加载失败
```bash
# 检查镜像文件
ls -la docker-images/

# 手动加载单个镜像
docker load -i docker-images/postgres_15-alpine.tar

# 验证镜像加载
docker images
```

### 日志分析

#### 应用日志
```bash
# 查看应用启动日志
docker-compose logs hypertrace-demo-app | grep -i error

# 查看 JVM 内存使用
docker stats hypertrace-demo-app
```

#### 数据库连接问题
```bash
# 检查数据库状态
docker-compose exec postgres pg_isready -U postgres

# 查看数据库日志
docker-compose logs postgres
```

#### Kafka 连接问题
```bash
# 检查 Kafka 状态 (KRaft 模式)
docker-compose exec kafka kafka-topics --bootstrap-server localhost:9092 --list

# 查看 Kafka 日志
docker-compose logs kafka

# 检查 KRaft 元数据
docker-compose exec kafka kafka-metadata-shell --snapshot /var/lib/kafka/data/__cluster_metadata-0/00000000000000000000.log
```

## 配置说明

### 环境变量配置

主要配置文件：`docker-compose.yml`

#### 数据库配置
- `POSTGRES_DB`: 数据库名称
- `POSTGRES_USER`: 数据库用户
- `POSTGRES_PASSWORD`: 数据库密码

#### Kafka 配置
- `KAFKA_BOOTSTRAP_SERVERS`: Kafka 服务器地址
- `KAFKA_ZOOKEEPER_CONNECT`: Zookeeper 连接地址

#### 应用配置
- `SPRING_PROFILES_ACTIVE`: Spring 配置文件
- `OTEL_SERVICE_NAME`: OpenTelemetry 服务名称
- `HT_SANITIZATION_CONFIG_ENDPOINT`: 脱敏配置服务地址

### 自定义配置

如需修改配置，编辑 `docker-compose.yml` 文件后重新启动：

```bash
# 修改配置后重启
docker-compose down
docker-compose up -d
```

## 性能优化

### 资源限制

在生产环境中，建议为容器设置资源限制：

```yaml
deploy:
  resources:
    limits:
      memory: 1G
      cpus: '0.5'
    reservations:
      memory: 512M
      cpus: '0.25'
```

### 数据持久化

重要数据已配置持久化存储：
- PostgreSQL 数据: `postgres-data` 卷
- Kafka 数据: `kafka-data` 卷
- 脱敏配置数据: `sanitization-postgres-data` 卷

## 安全建议

1. **修改默认密码**: 更改数据库默认密码
2. **网络隔离**: 使用 Docker 网络隔离服务
3. **端口限制**: 仅暴露必要的端口
4. **定期更新**: 定期更新镜像和依赖

## 支持

如遇到问题，请检查：
1. 系统要求是否满足
2. 端口是否被占用
3. Docker 服务是否正常运行
4. 日志中的错误信息

更多技术支持，请参考项目文档或联系开发团队。