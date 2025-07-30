#!/bin/bash

# 从 Kerberos 容器中提取 keytab 文件到本地
# 这样本地的 Spring Boot 应用就可以使用这些文件进行认证

set -e

echo "=== 提取 Kerberos Keytab 文件 ==="

# 检查容器是否在运行
if ! docker ps | grep -q kerberos-kdc; then
    echo "❌ KDC 容器没有运行，请先启动 docker-compose"
    echo "运行: docker-compose up -d kerberos-kdc"
    exit 1
fi

# 创建本地 keytab 目录
KEYTAB_DIR="./kerberos"
mkdir -p "$KEYTAB_DIR"

echo "📋 等待 KDC 初始化完成..."
sleep 10

# 从容器中复制 keytab 文件
echo "📥 复制 kafka-client.keytab..."
docker cp kerberos-kdc:/var/kerberos/kafka-client.keytab "$KEYTAB_DIR/kafka-client.keytab"

echo "📥 复制 kafka.keytab..."
docker cp kerberos-kdc:/var/kerberos/kafka.keytab "$KEYTAB_DIR/kafka.keytab"

# 设置文件权限
chmod 644 "$KEYTAB_DIR"/*.keytab

echo "✅ Keytab 文件已成功提取到 $KEYTAB_DIR 目录"

# 验证 keytab 文件
echo "🔍 验证 keytab 文件内容:"
echo "--- kafka-client.keytab ---"
klist -kt "$KEYTAB_DIR/kafka-client.keytab" || echo "无法读取 keytab，可能文件损坏"

echo "--- kafka.keytab ---"
klist -kt "$KEYTAB_DIR/kafka.keytab" || echo "无法读取 keytab，可能文件损坏"

echo ""
echo "🎯 现在可以启动 Spring Boot 应用:"
echo "   ./gradlew bootRun --args='--spring.profiles.active=kerberos'"
