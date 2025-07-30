#!/bin/bash

# 直接运行 Spring Boot 应用（不使用 Hypertrace Agent）

# 构建应用
echo "正在构建应用..."
./gradlew clean build -x test

if [ $? -ne 0 ]; then
    echo "构建失败"
    exit 1
fi

# 运行应用
echo "正在启动应用..."
java -Dspring.profiles.active=dev \
     -Dotel.instrumentation.kafka.enabled=true \
     -Dotel.instrumentation.messaging.enabled=true \
     -Dotel.instrumentation.spring-kafka.enabled=true
     -jar build/libs/hypertrace-demo-0.0.1-SNAPSHOT.jar
