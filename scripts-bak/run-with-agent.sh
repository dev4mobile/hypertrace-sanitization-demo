#!/bin/bash

# 使用 Hypertrace Java Agent 运行 Spring Boot 应用

# 检查 agent 是否存在
if [ ! -f "agents/hypertrace-agent.jar" ]; then
    echo "Hypertrace Agent 未找到，请先运行 ./scripts/download-agent.sh"
    exit 1
fi

# 构建应用
echo "正在构建应用..."
./gradlew clean build -x test

if [ $? -ne 0 ]; then
    echo "构建失败"
    exit 1
fi

# 设置环境变量
export OTEL_SERVICE_NAME=hypertrace-demo
export OTEL_RESOURCE_ATTRIBUTES=service.name=hypertrace-demo,service.version=1.0.0
export HT_REPORTING_ENDPOINT=http://localhost:4317
export HT_CONFIG_FILE=hypertrace-config.yaml
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
export HT_CAPTURE_KAFKA_BODY_REQUEST=true
export HT_CAPTURE_KAFKA_BODY_RESPONSE=true

# 优化的JVM参数 - 减少重复的metrics配置
JVM_OPTS="-javaagent:agents/hypertrace-agent-1.3.25.jar"
JVM_OPTS="$JVM_OPTS -Dhypertrace.service.name=user-service"
JVM_OPTS="$JVM_OPTS -Dspring.profiles.active=dev"

# 核心OpenTelemetry配置
JVM_OPTS="$JVM_OPTS -Dotel.instrumentation.kafka.enabled=true"
JVM_OPTS="$JVM_OPTS -Dotel.instrumentation.spring-kafka.enabled=true"
JVM_OPTS="$JVM_OPTS -Dotel.instrumentation.messaging.enabled=true"

# 简化的数据捕获配置
JVM_OPTS="$JVM_OPTS -Dht.data-capture.messaging.enabled=true"
JVM_OPTS="$JVM_OPTS -Dht.data-capture.messaging.message-body.enabled=true"

# 数据库instrumentation - 已禁用
JVM_OPTS="$JVM_OPTS -Dotel.instrumentation.jdbc.enabled=false"
JVM_OPTS="$JVM_OPTS -Dotel.instrumentation.jpa.enabled=false"
JVM_OPTS="$JVM_OPTS -Dotel.instrumentation.hibernate.enabled=false"

# 禁用重复的metrics收集
JVM_OPTS="$JVM_OPTS -Dotel.instrumentation.kafka.experimental-metrics.enabled=false"
JVM_OPTS="$JVM_OPTS -Dotel.instrumentation.kafka.metrics.enabled=false"

# 运行应用
echo "正在启动应用..."
java $JVM_OPTS -jar build/libs/hypertrace-demo-0.0.1-SNAPSHOT.jar
