#!/bin/bash

echo "=== 重启 Kafka 并启用 Hypertrace Agent ==="

echo "1. 停止当前的 Kafka 服务..."
docker-compose stop kafka

echo "2. 等待 Kafka 完全停止..."
sleep 5

echo "3. 检查 Hypertrace Agent 文件..."
if [ ! -f "agents/hypertrace-agent.jar" ]; then
    echo "❌ 错误: agents/hypertrace-agent.jar 不存在"
    echo "请确保 Hypertrace Agent 文件存在"
    exit 1
fi

# hypertrace-config-kafka.yaml 文件检查已移除

echo "4. 启动带有 Hypertrace Agent 的 Kafka..."
docker-compose up -d kafka

echo "5. 等待 Kafka 启动..."
sleep 15

echo "6. 检查 Kafka 状态..."
if docker ps | grep kafka > /dev/null; then
    echo "✅ Kafka 启动成功"
    echo "查看 Kafka 日志: docker logs kafka"
else
    echo "❌ Kafka 启动失败"
    echo "查看错误日志: docker logs kafka"
    exit 1
fi

echo "7. 检查 Kafka 连接..."
if docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list > /dev/null 2>&1; then
    echo "✅ Kafka 连接正常"
else
    echo "❌ Kafka 连接失败"
    echo "查看 Kafka 日志: docker logs kafka"
    exit 1
fi

echo ""
echo "=== 配置完成 ==="
echo "Kafka Broker 现在已启用 Hypertrace Agent 监控"
echo ""
echo "监控信息:"
echo "- 服务名: kafka-broker"
echo "- Jaeger UI: http://localhost:16686"
echo "- 在 Jaeger 中查找 'kafka-broker' 服务"
echo ""
echo "测试建议:"
echo "1. 发送消息到 Kafka"
echo "2. 在 Jaeger UI 中查看 kafka-broker 服务的 traces"
echo "3. 检查消息体是否被捕获"
echo ""
echo "查看 Kafka 日志: docker logs kafka -f"
