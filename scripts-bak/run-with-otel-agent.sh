#!/bin/bash

# 检查应用是否已构建
if [ ! -f "build/libs/hypertrace-demo-0.0.1-SNAPSHOT.jar" ]; then
    echo "应用未构建，正在构建..."
    ./gradlew clean build -x test
fi

echo "使用 OpenTelemetry Java Agent 启动应用..."
java \
  -javaagent:agents/opentelemetry-javaagent-1.33.5.jar \
  -Dotel.service.name=hypertrace-demo-otel \
  -Dotel.resource.attributes=service.name=hypertrace-demo-otel \
  -Dotel.traces.exporter=otlp \
  -Dotel.exporter.otlp.protocol=grpc \
  -Dotel.exporter.otlp.endpoint=http://localhost:4317 \
  -Dotel.propagators=tracecontext,baggage,b3 \
  -Dspring.profiles.active=dev \
  -Dotel.instrumentation.kafka.enabled=true \
  -Dotel.instrumentation.spring-kafka.enabled=true \
  -Dotel.instrumentation.messaging.enabled=true \
  -Dotel.instrumentation.kafka.consumer.batch-receive.enabled=false \
  -Dotel.instrumentation.messaging.experimental.capture-payload.enabled=true \
  -Dotel.instrumentation.kafka.experimental.capture-payload.enabled=true \
  -Dotel.instrumentation.messaging.capture-payload-body-size=2048 \
  -Dotel.instrumentation.kafka.producer.capture-headers=all \
  -Dotel.instrumentation.kafka.consumer.capture-headers=all \
  -Dotel.instrumentation.sql.experimental.capture-statement.enabled=true \
  -Dotel.instrumentation.kafka-clients.enabled=true \
  -Dotel.instrumentation.kafka.consumer.enabled=true \
  -Dotel.instrumentation.kafka.producer.enabled=true \
  -Dotel.traces.sampler=always_on \
  -Dotel.metrics.exporter=none \
  -Dotel.instrumentation.messaging.experimental.receive-telemetry.enabled=true \
  -jar build/libs/hypertrace-demo-0.0.1-SNAPSHOT.jar
