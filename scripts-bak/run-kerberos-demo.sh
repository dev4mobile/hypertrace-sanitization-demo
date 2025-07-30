#!/bin/bash

# Kafka Kerberos 演示启动脚本（使用 PLAINTEXT 连接）
# 使用方法: ./scripts/run-kerberos-demo.sh

echo "=== 启动 Kafka 应用 (Kerberos 演示模式) ==="

# 检查 Kafka 是否运行
if ! nc -z localhost 9092 2>/dev/null; then
    echo "错误: Kafka 服务未运行，请先启动 Kafka"
    echo "运行: docker-compose up -d kafka"
    exit 1
fi

echo "✓ Kafka 服务正在运行"

# 构建应用
echo "构建应用..."
./gradlew build -x test --quiet

if [ $? -ne 0 ]; then
    echo "构建失败，退出"
    exit 1
fi

echo "✓ 应用构建完成"

# 检查 hypertrace-agent 文件
AGENT_FILE="agents/hypertrace-agent-1.3.25.jar"
if [ ! -f "$AGENT_FILE" ]; then
    echo "警告: $AGENT_FILE 不存在，尝试使用现有的 agent 文件..."
    AGENT_FILE="agents/hypertrace-agent.jar"
    if [ ! -f "$AGENT_FILE" ]; then
        echo "错误: 找不到 hypertrace-agent 文件"
        echo "请确保 agents/ 目录下有 hypertrace-agent jar 文件"
        exit 1
    fi
fi

echo "✓ 使用 Hypertrace Agent: $AGENT_FILE"

# JVM 基础参数
JVM_OPTS="-Xmx512m -Xms256m"

# Hypertrace Agent 配置
HYPERTRACE_OPTS="-javaagent:$AGENT_FILE"
HYPERTRACE_OPTS="$HYPERTRACE_OPTS -Dhypertrace.service.name=user-service"

# OpenTelemetry Kafka 配置
OTEL_KAFKA_OPTS="-Dotel.instrumentation.kafka.enabled=true"
OTEL_KAFKA_OPTS="$OTEL_KAFKA_OPTS -Dotel.instrumentation.spring-kafka.enabled=true"
OTEL_KAFKA_OPTS="$OTEL_KAFKA_OPTS -Dotel.instrumentation.messaging.enabled=true"
OTEL_KAFKA_OPTS="$OTEL_KAFKA_OPTS -Dotel.instrumentation.messaging.experimental.receive-telemetry.enabled=true"
OTEL_KAFKA_OPTS="$OTEL_KAFKA_OPTS -Dotel.instrumentation.messaging.experimental.capture-payload.enabled=true"
OTEL_KAFKA_OPTS="$OTEL_KAFKA_OPTS -Dotel.instrumentation.kafka.experimental.capture-payload.enabled=true"
OTEL_KAFKA_OPTS="$OTEL_KAFKA_OPTS -Dotel.instrumentation.kafka-clients.enabled=true"
OTEL_KAFKA_OPTS="$OTEL_KAFKA_OPTS -Dotel.instrumentation.kafka.consumer.enabled=true"
OTEL_KAFKA_OPTS="$OTEL_KAFKA_OPTS -Dotel.instrumentation.kafka.producer.enabled=true"

# Hypertrace 数据捕获配置
HT_DATA_CAPTURE_OPTS="-Dht.data-capture.messaging.enabled=true"
HT_DATA_CAPTURE_OPTS="$HT_DATA_CAPTURE_OPTS -Dht.data-capture.messaging.message-body.enabled=true"
HT_DATA_CAPTURE_OPTS="$HT_DATA_CAPTURE_OPTS -Dht.data-capture.messaging.consumer.enabled=true"
HT_DATA_CAPTURE_OPTS="$HT_DATA_CAPTURE_OPTS -Dht.data-capture.messaging.producer.enabled=true"

# OpenTelemetry 数据库配置 - 已禁用
OTEL_DB_OPTS="-Dotel.instrumentation.jdbc.enabled=false"
OTEL_DB_OPTS="$OTEL_DB_OPTS -Dotel.instrumentation.jpa.enabled=false"
OTEL_DB_OPTS="$OTEL_DB_OPTS -Dotel.instrumentation.hibernate.enabled=false"
OTEL_DB_OPTS="$OTEL_DB_OPTS -Dotel.instrumentation.jdbc.statement-sanitizer.enabled=false"
OTEL_DB_OPTS="$OTEL_DB_OPTS -Dotel.instrumentation.sql.experimental.capture-statement.enabled=true"
OTEL_DB_OPTS="$OTEL_DB_OPTS -Dotel.instrumentation.sql.experimental.capture-result-set.enabled=true"

# 合并所有 JVM 参数
ALL_JVM_OPTS="$JVM_OPTS $HYPERTRACE_OPTS $OTEL_KAFKA_OPTS $HT_DATA_CAPTURE_OPTS $OTEL_DB_OPTS"

# 应用配置
APP_OPTS="--spring.profiles.active=kerberos-demo"

echo "配置信息:"
echo "  模式: Kerberos 演示 (PLAINTEXT 连接)"
echo "  Kafka: localhost:9092"
echo "  Profile: kerberos-demo"
echo "  Hypertrace Agent: $AGENT_FILE"
echo "  服务名称: user-service"
echo "  消息体捕获: 启用"
echo "  数据库追踪: 启用"
echo ""

echo "启动应用..."
echo "JVM 参数预览:"
echo "  Agent: $HYPERTRACE_OPTS"
echo "  Kafka 追踪: 启用"
echo "  数据库追踪: 启用"
echo "  消息体捕获: 启用"
echo ""

export OTEL_SERVICE_NAME=hypertrace-demo
export HT_CAPTURE_KAFKA_BODY_REQUEST=true
export HT_CAPTURE_KAFKA_BODY_RESPONSE=true

java $ALL_JVM_OPTS -jar build/libs/hypertrace-demo-0.0.1-SNAPSHOT.jar $APP_OPTS
