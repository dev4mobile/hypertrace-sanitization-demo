#!/bin/bash

# 使用最新的 OpenTelemetry Java Agent 运行应用
# 专门针对 Spring Boot 3.x 和 Kafka 消息体捕获优化

# 检查应用是否已构建
# if [ ! -f "build/libs/hypertrace-demo-0.0.1-SNAPSHOT.jar" ]; then
#     echo "应用未构建，正在构建..."

# fi

 ./gradlew clean build -x test

echo "使用最新的 OpenTelemetry Java Agent 启动应用..."

# 设置环境变量
export OTEL_SERVICE_NAME=hypertrace-demo
export OTEL_RESOURCE_ATTRIBUTES=service.name=hypertrace-demo,service.version=1.0.0
export OTEL_TRACES_EXPORTER=otlp
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
export OTEL_PROPAGATORS=tracecontext,baggage,b3
export OTEL_TRACES_SAMPLER=always_on
export OTEL_METRICS_EXPORTER=none
export OTEL_LOGS_EXPORTER=none

# 启动应用，使用最新的 OpenTelemetry 配置
java \
  -javaagent:agents/opentelemetry-javaagent-2.18.0.jar \
  -Dspring.profiles.active=dev \
  -Dotel.service.name=hypertrace-demo \
  -Dotel.resource.attributes=service.name=hypertrace-demo \
  -Dotel.traces.exporter=otlp \
  -Dotel.exporter.otlp.protocol=grpc \
  -Dotel.exporter.otlp.endpoint=http://localhost:4317 \
  -Dotel.propagators=tracecontext,baggage,b3 \
  -Dotel.traces.sampler=always_on \
  -Dotel.metrics.exporter=none \
  -Dotel.logs.exporter=none \
  -Dotel.instrumentation.kafka.enabled=true \
  -Dotel.instrumentation.spring-kafka.enabled=true \
  -Dotel.instrumentation.messaging.enabled=true \
  -Dotel.instrumentation.kafka-clients.enabled=true \
  -Dotel.instrumentation.kafka.consumer.enabled=true \
  -Dotel.instrumentation.kafka.producer.enabled=true \
  -Dotel.instrumentation.messaging.experimental.receive-telemetry.enabled=true \
  -Dotel.instrumentation.messaging.experimental.capture-payload.enabled=true \
  -Dotel.instrumentation.kafka.experimental.capture-payload.enabled=true \
  -Dotel.instrumentation.kafka.producer.capture-headers=all \
  -Dotel.instrumentation.kafka.consumer.capture-headers=all \
  -Dotel.instrumentation.messaging.capture-payload-body-size=8192 \
  -Dotel.instrumentation.kafka.experimental.capture-payload-body-size=8192 \
  -Dotel.instrumentation.jdbc.enabled=false \
  -Dotel.instrumentation.jpa.enabled=false \
  -Dotel.instrumentation.hibernate.enabled=false \
  -Dotel.instrumentation.kafka.experimental.capture-message-body=true \
  -Dotel.instrumentation.kafka.experimental.message-body-max-size=2048 \
  -Dotel.instrumentation.http.experimental.capture-request-body=true \
  -Dotel.instrumentation.http.experimental.capture-response-body=true \
  -Dotel.instrumentation.http.experimental.message-body-max-size=2048 \
  -jar build/libs/hypertrace-demo-0.0.1-SNAPSHOT.jar
