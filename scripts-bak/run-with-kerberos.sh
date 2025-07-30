#!/bin/bash

# Kafka Kerberos 认证启动脚本
# 使用方法: ./scripts/run-with-kerberos.sh

echo "=== 启动 Kafka 应用 (Kerberos 认证) ==="

# 暂时使用 default profile，因为 Kafka 现在运行在 PLAINTEXT 模式
export SPRING_PROFILES_ACTIVE=default

# Kerberos 配置路径（暂时不使用）
# export KERBEROS_PRINCIPAL="kafka-client@EXAMPLE.COM"
# export KERBEROS_KEYTAB="./kerberos/kafka-client.keytab"
# export KERBEROS_SERVICE_NAME="kafka"

# 配置文件路径（暂时不使用）
# export JAAS_CONFIG="src/main/resources/kafka_client_jaas.conf"
# export KRB5_CONFIG="src/main/resources/krb5.conf"



# 检查 hypertrace-agent 文件
AGENT_FILE="agents/hypertrace-agent-1.3.25.jar"
if [ ! -f "$AGENT_FILE" ]; then
    echo "警告: $AGENT_FILE 不存在，尝试使用现有的 agent 文件..."
    AGENT_FILE="agents/hypertrace-agent.jar"
    if [ ! -f "$AGENT_FILE" ]; then
        echo "错误: 找不到 hypertrace-agent 文件"
        echo "请确保 agents/ 目录下有 hypertrace-agent jar 文件"
        exit 1
    fi
fi

echo "✓ 使用 Hypertrace Agent: $AGENT_FILE"

# JVM 基础参数
JVM_OPTS="-Xmx512m -Xms256m"

# Hypertrace Agent 配置
HYPERTRACE_OPTS="-javaagent:$AGENT_FILE"
HYPERTRACE_OPTS="$HYPERTRACE_OPTS -Dhypertrace.service.name=user-service"

# OpenTelemetry Kafka 配置
OTEL_KAFKA_OPTS="-Dotel.instrumentation.kafka.enabled=true"
OTEL_KAFKA_OPTS="$OTEL_KAFKA_OPTS -Dotel.instrumentation.spring-kafka.enabled=true"
OTEL_KAFKA_OPTS="$OTEL_KAFKA_OPTS -Dotel.instrumentation.messaging.enabled=true"
OTEL_KAFKA_OPTS="$OTEL_KAFKA_OPTS -Dotel.instrumentation.messaging.experimental.receive-telemetry.enabled=true"
OTEL_KAFKA_OPTS="$OTEL_KAFKA_OPTS -Dotel.instrumentation.messaging.experimental.capture-payload.enabled=true"
OTEL_KAFKA_OPTS="$OTEL_KAFKA_OPTS -Dotel.instrumentation.kafka.experimental.capture-payload.enabled=true"
OTEL_KAFKA_OPTS="$OTEL_KAFKA_OPTS -Dotel.instrumentation.kafka-clients.enabled=true"
OTEL_KAFKA_OPTS="$OTEL_KAFKA_OPTS -Dotel.instrumentation.kafka.consumer.enabled=true"
OTEL_KAFKA_OPTS="$OTEL_KAFKA_OPTS -Dotel.instrumentation.kafka.producer.enabled=true"

# Hypertrace 数据捕获配置
HT_DATA_CAPTURE_OPTS="-Dht.data-capture.messaging.enabled=true"
HT_DATA_CAPTURE_OPTS="$HT_DATA_CAPTURE_OPTS -Dht.data-capture.messaging.message-body.enabled=true"
HT_DATA_CAPTURE_OPTS="$HT_DATA_CAPTURE_OPTS -Dht.data-capture.messaging.consumer.enabled=true"
HT_DATA_CAPTURE_OPTS="$HT_DATA_CAPTURE_OPTS -Dht.data-capture.messaging.producer.enabled=true"

# OpenTelemetry 数据库配置 - 已禁用
OTEL_DB_OPTS="-Dotel.instrumentation.jdbc.enabled=false"
OTEL_DB_OPTS="$OTEL_DB_OPTS -Dotel.instrumentation.jpa.enabled=false"
OTEL_DB_OPTS="$OTEL_DB_OPTS -Dotel.instrumentation.hibernate.enabled=false"
OTEL_DB_OPTS="$OTEL_DB_OPTS -Dotel.instrumentation.jdbc.statement-sanitizer.enabled=false"
OTEL_DB_OPTS="$OTEL_DB_OPTS -Dotel.instrumentation.sql.experimental.capture-statement.enabled=true"
OTEL_DB_OPTS="$OTEL_DB_OPTS -Dotel.instrumentation.sql.experimental.capture-result-set.enabled=true"

# Kerberos JVM 参数（暂时禁用）
KERBEROS_OPTS=""
# KERBEROS_OPTS="-Djava.security.auth.login.config=${JAAS_CONFIG}"
# KERBEROS_OPTS="${KERBEROS_OPTS} -Djava.security.krb5.conf=${KRB5_CONFIG}"
# KERBEROS_OPTS="${KERBEROS_OPTS} -Djavax.security.auth.useSubjectCredsOnly=false"

# 调试选项（可选）
# if [ "$DEBUG" = "true" ]; then
#     KERBEROS_OPTS="${KERBEROS_OPTS} -Dsun.security.krb5.debug=true"
#     KERBEROS_OPTS="${KERBEROS_OPTS} -Dsun.security.jgss.debug=true"
#     echo "启用 Kerberos 调试模式"
# fi

# 合并所有 JVM 参数
ALL_JVM_OPTS="$JVM_OPTS $HYPERTRACE_OPTS $OTEL_KAFKA_OPTS $HT_DATA_CAPTURE_OPTS $OTEL_DB_OPTS $KERBEROS_OPTS"

# 应用配置（暂时使用默认配置）
APP_OPTS="--spring.profiles.active=default"
# APP_OPTS="${APP_OPTS} --kerberos.principal=${KERBEROS_PRINCIPAL}"
# APP_OPTS="${APP_OPTS} --kerberos.keytab=${KERBEROS_KEYTAB}"
# APP_OPTS="${APP_OPTS} --kerberos.service.name=${KERBEROS_SERVICE_NAME}"
# APP_OPTS="${APP_OPTS} --kerberos.jaas.config=${JAAS_CONFIG}"
# APP_OPTS="${APP_OPTS} --kerberos.krb5.config=${KRB5_CONFIG}"

echo "配置信息:"
echo "  模式: PLAINTEXT 模式 (暂时不使用 Kerberos)"
echo "  Kafka 端口: localhost:9092"
echo "  Hypertrace Agent: $AGENT_FILE"
echo "  服务名称: user-service"
echo "  消息体捕获: 启用"
echo "  数据库追踪: 启用"
echo ""

# 检查配置文件是否存在（暂时跳过 Kerberos 检查）
echo "跳过 Kerberos 配置文件检查（当前使用 PLAINTEXT 模式）"

echo "构建应用..."
./gradlew build -x test

if [ $? -ne 0 ]; then
    echo "构建失败，退出"
    exit 1
fi

echo ""
echo "启动应用..."
echo "JVM 参数预览:"
echo "  Agent: $HYPERTRACE_OPTS"
echo "  Kafka 追踪: 启用"
echo "  数据库追踪: 启用"
echo "  消息体捕获: 启用"
echo "  Kerberos 认证: 启用"
echo ""

export OTEL_SERVICE_NAME=hypertrace-demo
export HT_CAPTURE_KAFKA_BODY_REQUEST=true
export HT_CAPTURE_KAFKA_BODY_RESPONSE=true

# 启动应用
java $ALL_JVM_OPTS -jar build/libs/hypertrace-demo-0.0.1-SNAPSHOT.jar $APP_OPTS
