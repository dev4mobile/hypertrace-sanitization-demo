#!/bin/bash

# 完整的 Kerberos 演示启动脚本

set -e

echo "🚀 启动 Hypertrace Kerberos 演示环境"
echo "======================================"

# 检查必要的工具
command -v docker >/dev/null 2>&1 || { echo "❌ 需要安装 Docker"; exit 1; }
command -v docker-compose >/dev/null 2>&1 || { echo "❌ 需要安装 Docker Compose"; exit 1; }

# 步骤 1: 启动 Docker 服务
echo ""
echo "📋 步骤 1: 启动 Docker 服务"
echo "停止现有容器..."
docker-compose down -v 2>/dev/null || true

echo "启动所有服务..."
docker-compose up -d

# 步骤 2: 等待服务启动
echo ""
echo "📋 步骤 2: 等待服务启动"
echo "等待 KDC 初始化... (60秒)"
sleep 60

echo "等待 Kafka 启动... (30秒)"
sleep 30

# 步骤 3: 验证服务状态
echo ""
echo "📋 步骤 3: 验证服务状态"
echo "检查容器状态:"
docker-compose ps

# 检查 KDC 是否正常
echo ""
echo "检查 KDC 状态:"
if docker exec kerberos-kdc kadmin.local -q "listprincs" > /dev/null 2>&1; then
    echo "✅ KDC 服务正常"
else
    echo "❌ KDC 服务异常"
    docker logs kerberos-kdc --tail 20
    exit 1
fi

# 检查 Kafka 是否正常
echo ""
echo "检查 Kafka 状态:"
if docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list > /dev/null 2>&1; then
    echo "✅ Kafka 服务正常"
else
    echo "❌ Kafka 服务异常"
    docker logs kafka --tail 20
    exit 1
fi

# 步骤 4: 提取 keytab 文件
echo ""
echo "📋 步骤 4: 提取 Keytab 文件"
./scripts/extract-keytabs.sh

# 步骤 5: 显示连接信息
echo ""
echo "🎯 环境就绪！连接信息:"
echo "================================"
echo "Kafka PLAINTEXT:     localhost:9092"
echo "Kafka SASL_PLAINTEXT: localhost:9093"
echo "Jaeger UI:           http://localhost:16686"
echo "PostgreSQL:          localhost:5432"
echo ""
echo "Kerberos 配置:"
echo "- Realm:             EXAMPLE.COM"
echo "- KDC:              localhost:88"
echo "- Admin Server:     localhost:749"
echo "- Client Principal: kafka-client@EXAMPLE.COM"
echo ""
echo "启动 Spring Boot 应用:"
echo "  ./gradlew bootRun --args='--spring.profiles.active=kerberos'"
echo ""
echo "或者运行测试:"
echo "  ./scripts/test-kerberos-auth.sh"
