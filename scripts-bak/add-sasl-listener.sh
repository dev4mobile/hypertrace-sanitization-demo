#!/bin/bash

# 动态添加SASL监听器到kafka
# 这个脚本在kafka运行时动态添加SASL_PLAINTEXT监听器

set -e

echo "=== 动态添加SASL监听器到kafka ==="

# 检查kafka是否运行
if ! docker exec kafka kafka-broker-api-versions --bootstrap-server localhost:9092 > /dev/null 2>&1; then
    echo "错误: kafka服务未运行或无法连接"
    exit 1
fi

echo "✅ kafka服务正在运行"

# 步骤1: 添加SASL监听器
echo "步骤1: 添加SASL监听器..."
docker exec kafka kafka-configs --bootstrap-server localhost:9092 --entity-type brokers --entity-name 1 --alter --add-config 'listeners=PLAINTEXT://0.0.0.0:29092,PLAINTEXT_HOST://0.0.0.0:9092,SASL_PLAINTEXT://0.0.0.0:29093,SASL_PLAINTEXT_HOST://0.0.0.0:9093'

# 步骤2: 更新监听器安全协议映射
echo "步骤2: 更新监听器安全协议映射..."
docker exec kafka kafka-configs --bootstrap-server localhost:9092 --entity-type brokers --entity-name 1 --alter --add-config 'listener.security.protocol.map=PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_PLAINTEXT_HOST:SASL_PLAINTEXT'

# 步骤3: 更新广播监听器
echo "步骤3: 更新广播监听器..."
docker exec kafka kafka-configs --bootstrap-server localhost:9092 --entity-type brokers --entity-name 1 --alter --add-config 'advertised.listeners=PLAINTEXT://kafka.example.com:29092,PLAINTEXT_HOST://localhost:9092,SASL_PLAINTEXT://kafka.example.com:29093,SASL_PLAINTEXT_HOST://localhost:9093'

# 步骤4: 添加SASL配置
echo "步骤4: 添加SASL配置..."
docker exec kafka kafka-configs --bootstrap-server localhost:9092 --entity-type brokers --entity-name 1 --alter --add-config 'sasl.enabled.mechanisms=GSSAPI'

# 步骤5: 添加SASL服务名
echo "步骤5: 添加SASL服务名..."
docker exec kafka kafka-configs --bootstrap-server localhost:9092 --entity-type brokers --entity-name 1 --alter --add-config 'sasl.kerberos.service.name=kafka'

# 步骤6: 验证配置
echo "步骤6: 验证配置..."
docker exec kafka kafka-configs --bootstrap-server localhost:9092 --entity-type brokers --entity-name 1 --describe

echo "✅ SASL监听器配置完成！"
echo ""
echo "现在kafka支持以下协议："
echo "- PLAINTEXT: localhost:9092"
echo "- SASL_PLAINTEXT: localhost:9093 (需要Kerberos认证)"
echo ""
echo "注意：SASL_PLAINTEXT端口需要Kerberos认证才能使用"
