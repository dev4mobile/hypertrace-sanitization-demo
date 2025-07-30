#!/bin/bash

# 使用 Kerberos 认证运行 Spring Boot 应用

echo "=== 启动 Spring Boot 应用 (Kerberos 认证) ==="

# 检查 agent 是否存在
if [ ! -f "agents/hypertrace-agent.jar" ]; then
    echo "Hypertrace Agent 未找到，请先运行 ./scripts/download-agent.sh"
    exit 1
fi

# 检查 Kerberos 配置文件
if [ ! -f "src/main/resources/krb5.conf" ]; then
    echo "错误: Kerberos 配置文件 src/main/resources/krb5.conf 不存在"
    exit 1
fi

if [ ! -f "src/main/resources/kafka_client_jaas.conf" ]; then
    echo "错误: JAAS 配置文件 src/main/resources/kafka_client_jaas.conf 不存在"
    exit 1
fi

if [ ! -f "kerberos/kafka-client.keytab" ]; then
    echo "错误: Kafka 客户端 keytab 文件不存在"
    echo "请确保 Kerberos KDC 服务正在运行并且 keytab 已生成"
    exit 1
fi

# 构建应用
echo "正在构建应用..."
./gradlew clean build -x test

if [ $? -ne 0 ]; then
    echo "构建失败"
    exit 1
fi

# 复制 keytab 文件到 resources 目录以便应用访问
echo "复制 keytab 文件..."
cp kerberos/kafka-client.keytab src/main/resources/

# 设置环境变量
export OTEL_SERVICE_NAME=hypertrace-demo-kerberos
export OTEL_RESOURCE_ATTRIBUTES=service.name=hypertrace-demo-kerberos,service.version=1.0.0
export HT_REPORTING_ENDPOINT=http://localhost:4317
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
export HT_CAPTURE_KAFKA_BODY_REQUEST=true
export HT_CAPTURE_KAFKA_BODY_RESPONSE=true

# Kerberos 系统属性
KERBEROS_OPTS="-Djava.security.auth.login.config=src/main/resources/kafka_client_jaas.conf"
KERBEROS_OPTS="$KERBEROS_OPTS -Djava.security.krb5.conf=src/main/resources/krb5.conf"
KERBEROS_OPTS="$KERBEROS_OPTS -Djavax.security.auth.useSubjectCredsOnly=false"

# 启用 Kerberos 调试（可选）
if [ "$DEBUG" = "true" ]; then
    KERBEROS_OPTS="$KERBEROS_OPTS -Dsun.security.krb5.debug=true"
    KERBEROS_OPTS="$KERBEROS_OPTS -Dsun.security.jgss.debug=true"
    echo "启用 Kerberos 调试模式"
fi

# 优化的 JVM 参数
JVM_OPTS="-javaagent:agents/hypertrace-agent-1.3.25-SNAPSHOT-all.jar"
JVM_OPTS="$JVM_OPTS -Dhypertrace.service.name=user-service-kerberos"
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

# 合并所有 JVM 参数
ALL_JVM_OPTS="$JVM_OPTS $KERBEROS_OPTS"

echo "配置信息:"
echo "  认证模式: Kerberos SASL"
echo "  Kafka 端口: localhost:9093 (SASL_PLAINTEXT)"
echo "  Kerberos Realm: EXAMPLE.COM"
echo "  Principal: kafka-client@EXAMPLE.COM"
echo "  KDC: kdc.example.com:88"
echo "  服务名称: user-service-kerberos"
echo "  配置文件: application-kerberos.yml"
echo ""

echo "启动应用..."
echo "JVM 参数预览:"
echo "  Agent: 已加载 Hypertrace Agent"
echo "  Kerberos: 已启用"
echo "  Kafka 追踪: 已启用"
echo "  数据库追踪: 已启用"
echo "  消息体捕获: 已启用"
echo ""

# 启动应用，使用 Kerberos 配置 profile
java $ALL_JVM_OPTS -jar build/libs/hypertrace-demo-0.0.1-SNAPSHOT.jar --spring.profiles.active=kerberos
