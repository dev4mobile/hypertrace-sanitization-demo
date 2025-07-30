#!/bin/bash

# 启动完整监控栈脚本
# 包括: Jaeger, Prometheus, Grafana, Zookeeper, Kafka, Kafka UI

echo "🚀 启动 Hypertrace 监控栈 + Kafka..."
echo "包含以下服务:"
echo "  - Jaeger (分布式追踪): http://localhost:16686"
echo "  - Prometheus (指标收集): http://localhost:9090"
echo "  - Grafana (可视化): http://localhost:3000 (admin/admin)"
echo "  - Kafka UI (Kafka 管理): http://localhost:8088"
echo "  - Zookeeper: localhost:2181"
echo "  - Kafka: localhost:9092"
echo ""

# 检查 Docker 和 Docker Compose 是否安装
if ! command -v docker &> /dev/null; then
    echo "❌ 错误: Docker 未安装！"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ 错误: Docker Compose 未安装！"
    exit 1
fi

# 检查 agents 是否存在
HYPERTRACE_AGENT="agents/hypertrace-agent.jar"
JMX_EXPORTER_AGENT="agents/jmx_prometheus_javaagent.jar"

if [ ! -f "$HYPERTRACE_AGENT" ]; then
    echo "❌ 错误: Hypertrace Agent 未找到 ($HYPERTRACE_AGENT)"
    echo "请先运行 ./scripts/download-agent.sh 或手动下载。"
    exit 1
fi

if [ ! -f "$JMX_EXPORTER_AGENT" ]; then
    echo "❌ 错误: JMX Prometheus Exporter 未找到 ($JMX_EXPORTER_AGENT)"
    echo "请先运行 ./scripts/download-jmx-exporter.sh 或手动下载。"
    exit 1
fi


# 启动服务
echo "📦 拉取最新镜像..."
docker-compose pull

echo "🔧 启动服务..."
docker-compose up -d

# 等待服务启动
echo "⏳ 等待服务启动..."
sleep 10

# 检查服务状态
echo "🔍 检查服务状态..."
docker-compose ps

# 等待 Kafka 完全启动
echo "⏳ 等待 Kafka 完全启动 (30秒)..."
sleep 30

# 创建默认测试 topic
echo "📝 创建默认测试 topic..."
./scripts/kafka-topics.sh create test-topic 2>/dev/null || echo "Topic 可能已存在"
./scripts/kafka-topics.sh create user-events 2>/dev/null || echo "Topic 可能已存在"

echo ""
echo "✅ 监控栈启动完成！"
echo ""
echo "🌐 访问地址:"
echo "  📊 Jaeger UI:     http://localhost:16686"
echo "  📈 Prometheus:    http://localhost:9090"
echo "  📋 Grafana:       http://localhost:3000 (admin/admin)"
echo "  🎛️  Kafka UI:      http://localhost:8088"
echo ""
echo "🔧 Kafka 连接信息:"
echo "  Bootstrap Servers: localhost:9092"
echo "  Zookeeper:         localhost:2181"
echo ""
echo "📚 下一步操作:"
echo "  1. 测试 Kafka: ./scripts/kafka-test.sh test-messages"
echo "  2. 启动应用: ./scripts/run-with-agent.sh"
echo "  3. 查看 topics: ./scripts/kafka-topics.sh list"
echo ""
echo "🛑 停止服务: docker-compose down"
