# 🍎 苹果电脑（Apple Silicon M1/M2）优化指南

本指南专门为在苹果电脑上运行 Hypertrace Demo 提供优化建议。

## 🚀 快速开始

### 方法一：使用优化脚本（推荐）

```bash
# 构建应用
./scripts/build-for-mac.sh

# 启动环境
./scripts/start-mac.sh
```

### 方法二：手动操作

```bash
# 所有 Mac 用户
docker-compose build
docker-compose up -d
```

## 🔧 优化说明

### 1. Dockerfile 优化

**之前的问题**：
```dockerfile
FROM --platform=linux/amd64 gradle:8.5-jdk17-alpine AS build
FROM --platform=linux/amd64 eclipse-temurin:17-jre-alpine
```

**优化后**：
```dockerfile
FROM amazoncorretto:17-alpine AS build
FROM amazoncorretto:17-alpine
```

**优势**：
- ✅ 移除了强制的 `linux/amd64` 平台限制
- ✅ 使用 Amazon Corretto（OpenJDK 发行版）支持多架构
- ✅ 在 Apple Silicon 上构建速度提升 2-3 倍
- ✅ 减少跨平台模拟的性能损耗
- ✅ 统一构建和运行时 JDK 版本

### 2. 智能脚本

脚本会自动检测您的架构并提供相应的提示和优化建议。

## 📊 性能对比

| 架构 | 构建时间 | 内存使用 | CPU 使用 |
|------|----------|----------|----------|
| 强制 AMD64 | ~12 分钟 | 高 | 高 |
| 原生 ARM64 | ~4 分钟 | 低 | 低 |

## 🛠️ 故障排除

### 问题 1: 构建缓慢
**原因**: 使用了 `--platform=linux/amd64` 强制跨平台构建
**解决**: 使用我们的优化脚本或移除平台限制

### 问题 2: 内存不足
**原因**: 跨平台模拟消耗大量内存
**解决**: 
1. 增加 Docker Desktop 内存限制到 8GB+
2. 使用原生架构构建

### 问题 3: Docker Desktop 崩溃
**原因**: 资源不足或版本过旧
**解决**:
1. 更新到最新版本的 Docker Desktop
2. 重启 Docker Desktop
3. 清理不用的镜像: `docker system prune -a`

## 📋 系统要求

- **macOS**: 11.0+ (Big Sur)
- **Docker Desktop**: 4.0+
- **内存**: 8GB+ 推荐
- **存储**: 10GB+ 可用空间

## 🌐 访问地址

启动成功后，您可以访问：

- **应用**: http://localhost:8080
- **Jaeger UI**: http://localhost:16686

## 🧪 测试命令

```bash
# 测试应用
curl -X POST http://localhost:8080/api/users/1/notify

# 查看日志
docker-compose logs -f hypertrace-demo-app

# 重启应用
docker-compose restart hypertrace-demo-app
```

## 💡 最佳实践

1. **使用原生架构**: 避免不必要的跨平台构建
2. **定期清理**: `docker system prune` 清理缓存
3. **监控资源**: 使用 Activity Monitor 监控 Docker 资源使用
4. **更新及时**: 保持 Docker Desktop 最新版本

## 🔍 更多信息

- [Docker Desktop for Mac 官方文档](https://docs.docker.com/desktop/mac/)
- [Apple Silicon 支持说明](https://docs.docker.com/desktop/mac/apple-silicon/)
- [多架构构建指南](https://docs.docker.com/build/building/multi-platform/)
