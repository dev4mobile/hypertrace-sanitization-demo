# 🚀 Hypertrace Demo 快速开始

一键部署 Hypertrace Java Agent 监控演示项目，支持分布式追踪、Kafka 集成和数据脱敏配置。

## ⚡ 快速部署

### 方法一：直接安装（推荐）

```bash
# 1. 克隆项目（如果还没有）
git clone <your-repo-url>
cd hypertrace-demo

# 2. 一键安装
./install.sh
```

### 方法二：打包分发

```bash
# 1. 打包项目
./package.sh

# 2. 分发到目标环境
scp dist/hypertrace-demo-1.0.0.tar.gz user@target-server:~/

# 3. 在目标环境安装
tar -xzf hypertrace-demo-1.0.0.tar.gz
cd hypertrace-demo-1.0.0
./install.sh
```

## 🧪 验证部署

```bash
# 运行自动化测试
./test-deployment.sh
```

## 🌐 访问服务

安装完成后，访问以下地址：

| 服务 | 地址 | 说明 |
|------|------|------|
| 🏠 应用主页 | http://localhost:8080 | Spring Boot 应用 |
| 📊 分布式追踪 | http://localhost:16686 | Jaeger UI |
| 🛡️ 脱敏配置 | http://localhost:3000 | 数据脱敏管理界面 |

## 🔧 常用命令

```bash
# 查看服务状态
docker-compose ps

# 查看应用日志
docker-compose logs -f hypertrace-demo-app

# 重启服务
docker-compose restart

# 停止服务
docker-compose down

# 完全清理
docker-compose down -v
```

## 📝 API 测试

```bash
# 创建用户
curl -X POST http://localhost:8080/api/users \
     -H "Content-Type: application/json" \
     -d '{"name":"张三","email":"zhangsan@example.com"}'

# 触发 Kafka 通知（生成分布式追踪）
curl -X POST http://localhost:8080/api/users/1/notify
```

## 🆘 故障排除

### 端口被占用
```bash
./install.sh --clean  # 清理后重新安装
```

### 服务启动失败
```bash
docker-compose logs    # 查看详细日志
./install.sh --verify # 验证安装状态
```

### 完全重置
```bash
./install.sh --uninstall  # 卸载
./install.sh --clean      # 清理后重新安装
```

## 📋 系统要求

- **Docker**: 20.10+
- **Docker Compose**: 2.0+
- **内存**: 4GB+
- **端口**: 8080, 16686, 9092, 2181, 5432, 3000, 3001, 55432

## 📚 更多信息

- 详细部署指南: [DEPLOYMENT.md](DEPLOYMENT.md)
- 项目文档: [README.md](README.md)
- Docker 优化: [DOCKER_OPTIMIZATION.md](DOCKER_OPTIMIZATION.md)

---

🎯 **目标**: 5 分钟内完成部署，开始体验分布式追踪和监控！