#!/bin/bash

# Docker 环境启动脚本
# 用于启动完整的 Hypertrace Demo 环境

set -e

echo "=== 启动 Hypertrace Demo Docker 环境 ==="

# 检查 Docker 和 Docker Compose 是否可用
if ! command -v docker &> /dev/null; then
    echo "错误: Docker 未安装或不在 PATH 中"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "错误: Docker Compose 未安装或不在 PATH 中"
    exit 1
fi

# 检查必要的文件是否存在
if [ ! -f "docker-compose.yml" ]; then
    echo "错误: docker-compose.yml 文件不存在"
    exit 1
fi

if [ ! -f "Dockerfile" ]; then
    echo "错误: Dockerfile 文件不存在"
    exit 1
fi

if [ ! -f "agents/hypertrace-agent.jar" ]; then
    echo "错误: Hypertrace Agent JAR 文件不存在"
    echo "请确保 agents/hypertrace-agent.jar 文件存在"
    exit 1
fi

# 清理旧的容器和镜像（可选）
if [ "$1" = "--clean" ]; then
    echo "清理旧的容器和镜像..."
    docker-compose down --volumes --remove-orphans
    docker system prune -f
fi

# 构建应用镜像
echo "构建 Hypertrace Demo 应用镜像..."
docker-compose build hypertrace-demo-app

# 启动所有服务
echo "启动所有服务..."
docker-compose up -d --build

# 等待服务启动
echo "等待服务启动..."
sleep 30

# 检查服务状态
echo "检查服务状态..."
docker-compose ps

# 显示日志
echo ""
echo "=== 服务启动完成 ==="
echo "应用访问地址:"
echo "  - Spring Boot 应用: http://localhost:8080"
echo "  - Jaeger UI (追踪): http://localhost:16686"
echo "  - PostgreSQL: localhost:5432"
echo "  - Kafka: localhost:9092"
echo ""
echo "测试命令:"
echo "  curl -X POST http://localhost:8080/api/users/1/notify"
echo ""
echo "查看日志:"
echo "  docker-compose logs -f hypertrace-demo-app"
echo ""
echo "停止服务:"
echo "  docker-compose down"
