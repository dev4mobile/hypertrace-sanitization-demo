#!/bin/bash

# 检查应用是否已构建
if [ ! -f "build/libs/hypertrace-demo-0.0.1-SNAPSHOT.jar" ]; then
    echo "应用未构建，正在构建..."
    ./gradlew build -x test
fi

echo "4. 使用 Hypertrace Agent 启动应用..."
java \
  -javaagent:agents/hypertrace-agent.jar \
  -Dhypertrace.config.file=hypertrace-config-enhanced.yaml \
  -Dhypertrace.service.name=hypertrace-demo \
  -Dotel.service.name=hypertrace-demo \
  -Dotel.resource.attributes=service.name=hypertrace-demo \
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
     -Dht.data-capture.messaging.message-body.max-size=32768 \
     -Dht.data-capture.messaging.kafka.enabled=true \
     -Dht.data-capture.messaging.kafka.producer.enabled=true \
     -Dht.data-capture.messaging.kafka.producer.capture-payload=true \
     -Dht.data-capture.messaging.kafka.consumer.enabled=true \
     -Dht.data-capture.messaging.kafka.consumer.capture-payload=true \
     -Dotel.instrumentation.jdbc.enabled=false \
     -Dotel.instrumentation.jpa.enabled=false \
     -Dotel.instrumentation.hibernate.enabled=false \
     -Dotel.instrumentation.jdbc.statement-sanitizer.enabled=false \
     -Dotel.instrumentation.sql.experimental.capture-statement.enabled=true \
     -Dotel.instrumentation.sql.experimental.capture-result-set.enabled=true \
     -Dotel.traces.sampler=always_on \
     -Dotel.metrics.exporter=none \
     -Dotel.logs.exporter=none \
     -Dotel.propagators=b3 \
     -jar build/libs/hypertrace-demo-0.0.1-SNAPSHOT.jar
