#!/bin/bash

# 使用 OpenTelemetry 配置文件运行应用
# 纯配置方案，无需修改业务代码

# 检查应用是否已构建
if [ ! -f "build/libs/hypertrace-demo-0.0.1-SNAPSHOT.jar" ]; then
    echo "应用未构建，正在构建..."
    ./gradlew clean build -x test
fi

echo "使用 OpenTelemetry 配置文件启动应用..."

# 使用配置文件启动应用
java \
  -javaagent:agents/opentelemetry-javaagent-1.33.5.jar \
  -Dotel.javaagent.configuration-file=otel-config.properties \
  -Dspring.profiles.active=dev \
  -jar build/libs/hypertrace-demo-0.0.1-SNAPSHOT.jar
