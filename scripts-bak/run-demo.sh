#!/bin/bash

# 启动 Spring Boot 应用 (演示模式)

echo "=== 启动 Spring Boot 应用 (演示模式) ==="

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
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
export HT_CAPTURE_KAFKA_BODY_REQUEST=true
export HT_CAPTURE_KAFKA_BODY_RESPONSE=true

# 优化的 JVM 参数
JVM_OPTS="-javaagent:agents/hypertrace-agent.jar"
JVM_OPTS="$JVM_OPTS -Dhypertrace.service.name=user-service-demo"
JVM_OPTS="$JVM_OPTS -Xmx512m -Xms256m"

# OpenTelemetry 配置
JVM_OPTS="$JVM_OPTS -Dotel.instrumentation.kafka.enabled=true"
JVM_OPTS="$JVM_OPTS -Dotel.instrumentation.spring-kafka.enabled=true"
JVM_OPTS="$JVM_OPTS -Dotel.instrumentation.messaging.enabled=true"

# Hypertrace 数据捕获
JVM_OPTS="$JVM_OPTS -Dht.data-capture.messaging.enabled=true"
JVM_OPTS="$JVM_OPTS -Dht.data-capture.messaging.message-body.enabled=true"
JVM_OPTS="$JVM_OPTS -Dht.data-capture.messaging.consumer.enabled=true"
JVM_OPTS="$JVM_OPTS -Dht.data-capture.messaging.producer.enabled=true"

# 数据库 instrumentation - 已禁用
JVM_OPTS="$JVM_OPTS -Dotel.instrumentation.jdbc.enabled=false"
JVM_OPTS="$JVM_OPTS -Dotel.instrumentation.jpa.enabled=false"
JVM_OPTS="$JVM_OPTS -Dotel.instrumentation.hibernate.enabled=false"

echo "配置信息:"
echo "  运行模式: 演示模式 (数据库重置)"
echo "  连接模式: PLAINTEXT (无认证)"
echo "  Kafka 端口: localhost:9092"
echo "  服务名称: user-service-demo"
echo "  配置文件: application-demo.yml"
echo "  数据库: 每次启动时重新创建表并导入测试数据"
echo ""

echo "启动应用..."
echo "JVM 参数预览:"
echo "  Agent: 已加载 Hypertrace Agent"
echo "  Kafka 追踪: 已启用"
echo "  数据库追踪: 已启用"
echo "  消息体捕获: 已启用"
echo "  调试日志: 已启用"
echo ""

# 启动应用，使用演示配置 profile
java $JVM_OPTS -jar build/libs/hypertrace-demo-0.0.1-SNAPSHOT.jar --spring.profiles.active=demo

echo ""
echo "演示应用已启动！"
echo "访问地址:"
echo "  应用: http://localhost:8080"
echo "  Jaeger UI: http://localhost:16686"
echo ""
echo "API 测试命令:"
echo "  创建用户: curl -X POST http://localhost:8080/api/users -H 'Content-Type: application/json' -d '{\"name\":\"李四\",\"email\":\"lisi@example.com\"}'"
echo "  获取用户: curl http://localhost:8080/api/users"
echo "  发送消息: curl -X POST http://localhost:8080/api/users/1/message -H 'Content-Type: application/json' -d '{\"message\":\"Hello Kafka!\"}'"