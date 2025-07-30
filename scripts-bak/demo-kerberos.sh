#!/bin/bash

# Kafka Kerberos 认证完整演示脚本
# 使用方法: ./scripts/demo-kerberos.sh

echo "=== Kafka Kerberos 认证完整演示 ==="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 函数：等待用户确认
wait_for_user() {
    echo -e "${YELLOW}按 Enter 键继续...${NC}"
    read
}

# 函数：检查命令执行结果
check_result() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1${NC}"
    else
        echo -e "${RED}✗ $1${NC}"
        exit 1
    fi
}

echo -e "${BLUE}这个演示将展示完整的 Kafka Kerberos 认证流程：${NC}"
echo "1. 设置 Kerberos KDC 服务器"
echo "2. 配置 Kafka 服务器支持 Kerberos"
echo "3. 生成和配置 keytab 文件"
echo "4. 启动支持 Kerberos 的应用"
echo "5. 测试 Kafka 消息发送和接收"
echo "6. 在 Jaeger 中查看追踪信息"
echo ""

wait_for_user

echo -e "${BLUE}步骤 1: 清理环境${NC}"
echo "停止现有服务..."
docker-compose down
check_result "环境清理完成"

echo ""
echo -e "${BLUE}步骤 2: 启动 Kerberos KDC 服务${NC}"
echo "启动 KDC 服务器..."
docker-compose up -d kerberos-kdc
check_result "KDC 服务启动"

echo "等待 KDC 服务初始化..."
sleep 20

# 检查 KDC 服务状态
if docker-compose ps kerberos-kdc | grep -q "Up"; then
    echo -e "${GREEN}✓ KDC 服务运行正常${NC}"
else
    echo -e "${RED}✗ KDC 服务启动失败${NC}"
    echo "查看日志:"
    docker-compose logs kerberos-kdc
    exit 1
fi

echo ""
echo -e "${BLUE}步骤 3: 查看 KDC 中创建的主体${NC}"
echo "KDC 中的主体列表:"
docker exec kerberos-kdc kadmin.local -q "listprincs" | grep -E "(kafka|admin)"

wait_for_user

echo ""
echo -e "${BLUE}步骤 4: 提取 keytab 文件${NC}"
echo "从 KDC 容器中提取 keytab 文件..."

# 等待 keytab 文件生成
for i in {1..30}; do
    if docker exec kerberos-kdc test -f /tmp/kafka-client.keytab; then
        break
    fi
    echo "等待 keytab 文件生成... ($i/30)"
    sleep 2
done

# 复制 keytab 文件
docker cp kerberos-kdc:/tmp/kafka-client.keytab ./kerberos/kafka-client.keytab
docker cp kerberos-kdc:/tmp/kafka.keytab ./kerberos/kafka.keytab
chmod 600 ./kerberos/kafka-client.keytab ./kerberos/kafka.keytab
check_result "Keytab 文件提取完成"

# 显示 keytab 内容
if command -v klist >/dev/null 2>&1; then
    echo "Kafka 客户端 keytab 内容:"
    klist -kt ./kerberos/kafka-client.keytab
fi

wait_for_user

echo ""
echo -e "${BLUE}步骤 5: 启动 Kafka 服务${NC}"
echo "启动 Zookeeper 和 Kafka..."
docker-compose up -d zookeeper kafka jaeger
check_result "Kafka 服务启动"

echo "等待 Kafka 服务初始化..."
sleep 30

# 检查 Kafka 服务状态
if docker-compose ps kafka | grep -q "Up"; then
    echo -e "${GREEN}✓ Kafka 服务运行正常${NC}"
else
    echo -e "${RED}✗ Kafka 服务启动失败${NC}"
    echo "查看日志:"
    docker-compose logs kafka
    exit 1
fi

echo ""
echo -e "${BLUE}步骤 6: 验证 Kafka 端口${NC}"
echo "检查 Kafka 端口..."
if nc -z localhost 9092; then
    echo -e "${GREEN}✓ PLAINTEXT 端口 (9092) 可访问${NC}"
else
    echo -e "${RED}✗ PLAINTEXT 端口 (9092) 不可访问${NC}"
fi

if nc -z localhost 9093; then
    echo -e "${GREEN}✓ SASL_PLAINTEXT 端口 (9093) 可访问${NC}"
else
    echo -e "${RED}✗ SASL_PLAINTEXT 端口 (9093) 不可访问${NC}"
fi

wait_for_user

echo ""
echo -e "${BLUE}步骤 7: 构建应用${NC}"
echo "构建 Spring Boot 应用..."
./gradlew build -x test --quiet
check_result "应用构建完成"

echo ""
echo -e "${BLUE}步骤 8: 启动应用（Kerberos 模式）${NC}"
echo "使用 Kerberos 认证启动应用..."
echo "应用将连接到 Kafka SASL_PLAINTEXT 端口 (9093)"

# 启动应用（后台运行）
./scripts/run-with-kerberos.sh &
APP_PID=$!

echo "应用 PID: $APP_PID"
echo "等待应用启动..."
sleep 45

# 检查应用是否启动成功
if kill -0 $APP_PID 2>/dev/null; then
    echo -e "${GREEN}✓ 应用启动成功${NC}"
else
    echo -e "${RED}✗ 应用启动失败${NC}"
    exit 1
fi

# 等待应用完全启动
echo "等待应用完全启动..."
for i in {1..20}; do
    if curl -s http://localhost:8080/actuator/health >/dev/null 2>&1; then
        echo -e "${GREEN}✓ 应用健康检查通过${NC}"
        break
    fi
    echo "等待中... ($i/20)"
    sleep 3
done

wait_for_user

echo ""
echo -e "${BLUE}步骤 9: 测试 Kafka 消息发送${NC}"
echo "发送测试消息到 Kafka..."

# 测试 API 调用
echo "调用用户通知 API..."
response=$(curl -s -w "%{http_code}" -X POST http://localhost:8080/api/users/1/notify)
http_code="${response: -3}"

if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✓ API 调用成功 (HTTP $http_code)${NC}"
    echo "消息已通过 Kerberos 认证发送到 Kafka"
else
    echo -e "${RED}✗ API 调用失败 (HTTP $http_code)${NC}"
fi

echo ""
echo "再发送几条测试消息..."
for i in {2..5}; do
    curl -s -X POST http://localhost:8080/api/users/$i/notify >/dev/null
    echo "发送消息 $i"
    sleep 1
done

wait_for_user

echo ""
echo -e "${BLUE}步骤 10: 查看追踪信息${NC}"
echo "打开 Jaeger UI 查看追踪信息..."
echo "URL: http://localhost:16686"
echo ""
echo "在 Jaeger 中查找："
echo "- 服务名: hypertrace-demo"
echo "- 操作: kafka.produce, kafka.consume"
echo "- 查看 span 中的 Kerberos 认证信息"

# 尝试打开浏览器
if command -v open >/dev/null 2>&1; then
    open http://localhost:16686
elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open http://localhost:16686
fi

wait_for_user

echo ""
echo -e "${BLUE}步骤 11: 查看服务日志${NC}"
echo "查看各服务的日志..."

echo -e "${YELLOW}KDC 服务日志:${NC}"
docker-compose logs --tail=10 kerberos-kdc

echo ""
echo -e "${YELLOW}Kafka 服务日志:${NC}"
docker-compose logs --tail=10 kafka

wait_for_user

echo ""
echo -e "${BLUE}演示完成！${NC}"
echo ""
echo -e "${GREEN}成功演示了以下功能:${NC}"
echo "✓ Kerberos KDC 服务器设置"
echo "✓ Kafka 服务器 Kerberos 认证配置"
echo "✓ 客户端 keytab 文件生成和配置"
echo "✓ Spring Boot 应用 Kerberos 认证"
echo "✓ Kafka 消息的安全发送和接收"
echo "✓ 分布式追踪和监控"
echo ""
echo -e "${YELLOW}服务访问信息:${NC}"
echo "- 应用: http://localhost:8080"
echo "- Jaeger UI: http://localhost:16686"
echo "- Kafka PLAINTEXT: localhost:9092"
echo "- Kafka SASL_PLAINTEXT: localhost:9093"
echo "- Kerberos KDC: localhost:88"
echo ""
echo -e "${YELLOW}清理环境:${NC}"
echo "docker-compose down"
echo ""

# 停止应用
echo "停止演示应用..."
kill $APP_PID 2>/dev/null
wait $APP_PID 2>/dev/null

echo -e "${GREEN}演示结束！${NC}"
