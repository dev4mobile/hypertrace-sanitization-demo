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

# 运行应用
echo "正在启动应用..."
java -javaagent:agents/hypertrace-agent.jar \
     -Dhypertrace.service.name=user-service \
     -Dspring.profiles.active=dev \
     -Dotel.instrumentation.kafka.enabled=true \
     -Dotel.instrumentation.spring-kafka.enabled=true \
     -Dotel.instrumentation.messaging.enabled=true \
     -Dotel.instrumentation.messaging.experimental.receive-telemetry.enabled=true \
     -Dotel.instrumentation.messaging.experimental.capture-payload.enabled=true \
     -Dotel.instrumentation.kafka.experimental.capture-payload.enabled=true \
     -Dotel.instrumentation.kafka-clients.enabled=true \
     -Dotel.instrumentation.kafka.consumer.enabled=true \
     -Dotel.instrumentation.kafka.producer.enabled=true \
     -Dht.data-capture.messaging.enabled=true \
     -Dht.data-capture.messaging.message-body.enabled=true \
     -Dht.data-capture.messaging.consumer.enabled=true \
     -Dht.data-capture.messaging.producer.enabled=true \
     -Dotel.instrumentation.jdbc.enabled=true \
     -Dotel.instrumentation.jpa.enabled=true \
     -Dotel.instrumentation.hibernate.enabled=true \
     -Dotel.instrumentation.jdbc.statement-sanitizer.enabled=false \
     -Dotel.instrumentation.sql.experimental.capture-statement.enabled=true \
     -Dotel.instrumentation.sql.experimental.capture-result-set.enabled=true \
     -jar build/libs/hypertrace-demo-0.0.1-SNAPSHOT.jar
