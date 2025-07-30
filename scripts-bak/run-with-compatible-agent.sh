#!/bin/bash

# 检查应用是否已构建
# if [ ! -f "build/libs/hypertrace-demo-0.0.1-SNAPSHOT.jar" ]; then
#     echo "应用未构建，正在构建..."

# fi

./gradlew build -x test

echo "正在启动应用（使用兼容版 Hypertrace Agent 配置）..."
java -javaagent:agents/hypertrace-agent.jar \
     -Dhypertrace.config.file=hypertrace-config-compatible.yaml \
     -Dhypertrace.service.name=hypertrace-demo \
     -Dspring.profiles.active=dev \
     -Dotel.instrumentation.kafka.enabled=true \
     -Dotel.instrumentation.spring-kafka.enabled=true \
     -Dotel.instrumentation.messaging.enabled=true \
     -Dotel.instrumentation.messaging.experimental.capture-payload.enabled=true \
     -Dotel.instrumentation.kafka.experimental.capture-payload.enabled=true \
     -Dotel.instrumentation.kafka-clients.enabled=true \
     -Dotel.instrumentation.kafka.consumer.enabled=true \
     -Dotel.instrumentation.kafka.producer.enabled=true \
     -Dht.data-capture.messaging.enabled=true \
     -Dht.data-capture.messaging.message-body.enabled=true \
     -Dht.data-capture.messaging.consumer.enabled=true \
     -Dht.data-capture.messaging.producer.enabled=true \
     -Dotel.instrumentation.jdbc.enabled=false \
     -Dotel.instrumentation.jpa.enabled=false \
     -Dotel.instrumentation.hibernate.enabled=false \
     -Dotel.instrumentation.jdbc.statement-sanitizer.enabled=false \
     -Dotel.instrumentation.sql.experimental.capture-statement.enabled=true \
     -Dotel.instrumentation.sql.experimental.capture-result-set.enabled=true \
     -Dotel.traces.sampler=always_on \
     -Dotel.propagators=b3 \
     -jar build/libs/hypertrace-demo-0.0.1-SNAPSHOT.jar
