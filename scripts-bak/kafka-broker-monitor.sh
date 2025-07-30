#!/bin/bash

# Kafka Broker 监控脚本
# 通过 JMX 和自定义指标生成 traces

echo "=== Kafka Broker 监控脚本 ==="

# 检查 Kafka 是否运行
if ! docker ps | grep -q kafka; then
    echo "❌ Kafka 容器未运行"
    exit 1
fi

echo "✅ Kafka 容器正在运行"

# 获取 Kafka 的 JMX 端口
KAFKA_JMX_PORT=19092

# 检查 JMX 连接
echo "检查 Kafka JMX 连接..."
if nc -z localhost $KAFKA_JMX_PORT; then
    echo "✅ Kafka JMX 端口可访问"
else
    echo "❌ Kafka JMX 端口不可访问"
fi

# 获取 Kafka 主题列表
echo "获取 Kafka 主题列表..."
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list

# 获取 Kafka 消费者组
echo "获取 Kafka 消费者组..."
docker exec kafka kafka-consumer-groups --bootstrap-server localhost:9092 --list

# 获取 Kafka 分区信息
echo "获取 Kafka 分区信息..."
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --describe --topic user-events

# 检查 Kafka 日志中的 OpenTelemetry 信息
echo "检查 Kafka OpenTelemetry 日志..."
docker logs kafka | grep -E "(opentelemetry|otel|trace|span)" | tail -5

echo "=== 监控完成 ==="
