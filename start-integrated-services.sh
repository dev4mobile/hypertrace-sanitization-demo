#!/bin/bash

# 启动整合后的 Hypertrace 和脱敏配置服务
# 作者: Kiro AI Assistant
# 日期: $(date +%Y-%m-%d)

set -e

echo "🚀 启动整合后的 Hypertrace 和脱敏配置服务..."

# 检查 Docker 和 Docker Compose 是否安装
if ! command -v docker &> /dev/null; then
    echo "❌ Docker 未安装，请先安装 Docker"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose 未安装，请先安装 Docker Compose"
    exit 1
fi

# 检查必要的文件是否存在
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ docker-compose.yml 文件不存在"
    exit 1
fi

if [ ! -f "sanitization-config-service/database/init-docker.sql" ]; then
    echo "❌ 脱敏配置服务数据库初始化文件不存在"
    exit 1
fi

# 清理旧的容器和网络（可选）
echo "🧹 清理旧的容器..."
docker-compose down --remove-orphans 2>/dev/null || true

# 构建镜像
echo "🔨 构建服务镜像..."
docker-compose build --no-cache

# 启动服务
echo "🚀 启动所有服务..."
docker-compose up -d

# 等待服务启动
echo "⏳ 等待服务启动..."
sleep 10

# 检查服务状态
echo "📊 检查服务状态..."
docker-compose ps

echo ""
echo "✅ 服务启动完成！"
echo ""
echo "📋 服务访问地址："
echo "  🔍 Jaeger UI (分布式追踪):     http://localhost:16686"
echo "  🏠 Hypertrace Demo App:       http://localhost:8080"
echo "  🛡️  脱敏配置管理界面:          http://localhost:3000"
echo "  🔧 脱敏配置 API:              http://localhost:3001"
echo "  🗄️  PostgreSQL (主数据库):     localhost:5432"
echo "  🗄️  PostgreSQL (脱敏配置):     localhost:55432"
echo "  📨 Kafka:                    localhost:9092"
echo ""
echo "🔧 管理命令："
echo "  查看日志: docker-compose logs -f [service_name]"
echo "  停止服务: docker-compose down"
echo "  重启服务: docker-compose restart [service_name]"
echo ""
echo "📝 注意事项："
echo "  - 首次启动可能需要几分钟来初始化数据库"
echo "  - 脱敏配置服务的数据库端口为 55432，避免与主数据库冲突"
echo "  - 所有服务都在同一个 Docker 网络中，可以通过服务名互相访问"