#!/bin/bash

# Docker 构建优化脚本

set -e

echo "=== Docker 构建优化选项 ==="
echo "1. 使用优化后的 Dockerfile (推荐)"
echo "2. 使用 BuildKit 缓存挂载 (需要 Docker BuildKit)"
echo "3. 使用原始 Dockerfile"
echo ""

read -p "请选择构建方式 (1-3): " choice

IMAGE_NAME="hypertrace-demo"
TAG="latest"

case $choice in
    1)
        echo "使用优化后的 Dockerfile 构建..."
        docker build -f Dockerfile.optimized -t ${IMAGE_NAME}:${TAG} .
        ;;
    2)
        echo "使用 BuildKit 缓存挂载构建..."
        echo "注意: 需要启用 Docker BuildKit"
        export DOCKER_BUILDKIT=1
        docker build -f Dockerfile.buildkit -t ${IMAGE_NAME}:${TAG} .
        ;;
    3)
        echo "使用原始 Dockerfile 构建..."
        docker build -f Dockerfile -t ${IMAGE_NAME}:${TAG} .
        ;;
    *)
        echo "无效选择，使用优化后的 Dockerfile..."
        docker build -f Dockerfile.optimized -t ${IMAGE_NAME}:${TAG} .
        ;;
esac

echo ""
echo "=== 构建完成 ==="
echo "镜像名称: ${IMAGE_NAME}:${TAG}"
echo ""
echo "运行命令:"
echo "docker run -p 8080:8080 ${IMAGE_NAME}:${TAG}"
echo ""
echo "=== 优化效果说明 ==="
echo "1. 分层缓存: Gradle wrapper 和依赖下载被分离到不同层"
echo "2. 源码变更时，只需重新构建最后几层"
echo "3. 依赖变更时，只需重新下载依赖，不需要重新下载 Gradle"
echo "4. BuildKit 版本使用缓存挂载，可以跨构建保持缓存"
