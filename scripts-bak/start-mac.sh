#!/bin/bash

# 苹果电脑启动脚本
# 自动检测架构并使用最优配置

set -e

echo "🍎 Apple Silicon 优化启动脚本"
echo "================================"

# 检测架构
ARCH=$(uname -m)
echo "检测到架构: $ARCH"

# 检查 Docker 是否运行
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker 未运行，请先启动 Docker Desktop"
    exit 1
fi

echo ""
echo "🚀 启动 Hypertrace Demo 环境..."

# 启动标准配置
echo "ℹ️  使用标准配置"
docker-compose up -d

echo ""
echo "⏳ 等待服务启动..."
sleep 10

echo ""
echo "📊 检查服务状态..."
docker-compose ps

echo ""
echo "✅ 环境启动完成！"
echo ""
echo "🌐 访问地址："
echo "   应用: http://localhost:8080"
echo "   Jaeger UI: http://localhost:16686"
echo ""
echo "📋 常用命令："
echo "   查看日志: docker-compose logs -f hypertrace-demo-app"
echo "   停止环境: docker-compose down"
echo "   重启应用: docker-compose restart hypertrace-demo-app"
echo ""
echo "🧪 测试应用："
echo "   curl -X POST http://localhost:8080/api/users/1/notify"
