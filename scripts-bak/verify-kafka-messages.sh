#!/bin/bash

echo "=== Kafka 消息验证脚本 ==="
echo "通过多种方式验证 Kafka 消息内容"
echo ""

# 检查应用是否运行
check_app_running() {
    if ! curl -f -s http://localhost:8080/actuator/health > /dev/null; then
        echo "❌ 应用未运行"
        return 1
    fi
    echo "✅ 应用正在运行"
    return 0
}

# 检查 Kafka 是否运行
check_kafka_running() {
    if ! docker ps | grep -q kafka; then
        echo "❌ Kafka 容器未运行"
        return 1
    fi
    echo "✅ Kafka 正在运行"
    return 0
}

echo "1. 检查服务状态..."
if ! check_app_running || ! check_kafka_running; then
    echo ""
    echo "请确保以下服务正在运行："
    echo "- docker-compose up -d (启动 Kafka 和监控栈)"
    echo "- ./scripts/run-with-otel-config.sh (启动应用)"
    exit 1
fi

echo ""
echo "2. 创建测试用户..."

# 创建用户
USER_RESPONSE=$(curl -s -X POST http://localhost:8080/api/users \
    -H "Content-Type: application/json" \
    -d '{
        "name": "Message Verification User",
        "email": "verify@example.com",
        "phone": "13800138999"
    }')

echo "用户创建响应: $USER_RESPONSE"
USER_ID=$(echo $USER_RESPONSE | jq -r '.id')

if [ "$USER_ID" = "null" ] || [ -z "$USER_ID" ]; then
    echo "❌ 无法创建用户"
    exit 1
fi

echo "✅ 用户创建成功，ID: $USER_ID"

echo ""
echo "3. 发送 Kafka 消息..."

# 发送通知
NOTIFY_RESPONSE=$(curl -s -w "HTTP_CODE:%{http_code}" -X POST http://localhost:8080/api/users/$USER_ID/notify)
echo "通知响应: $NOTIFY_RESPONSE"

echo ""
echo "4. 等待消息处理..."
sleep 3

echo ""
echo "5. 验证消息内容的多种方式："
echo ""

echo "方式1: 查看 Jaeger 追踪"
echo "🔗 Jaeger UI: http://localhost:16686"
echo "- 选择服务: hypertrace-demo"
echo "- 查找最新的 POST /api/users/{id}/notify 追踪"
echo "- 检查 Kafka 相关的 span 属性"
echo ""

echo "方式2: 查看 Kafka UI"
echo "🔗 Kafka UI: http://localhost:8088"
echo "- 导航到 Topics -> user-events"
echo "- 查看 Messages 标签页"
echo "- 应该能看到刚发送的 JSON 消息"
echo ""

echo "方式3: 使用 Kafka 命令行工具查看消息"
echo "执行以下命令查看最新消息："
echo ""
echo "docker exec kafka kafka-console-consumer \\"
echo "  --topic user-events \\"
echo "  --bootstrap-server localhost:9092 \\"
echo "  --from-beginning \\"
echo "  --max-messages 5"
echo ""

echo "方式4: 检查应用日志"
echo "在应用启动的终端中查找以下日志："
echo "- '#### -> Producing message -> {JSON内容}'"
echo "- '#### -> Consumed message -> User{...}'"
echo ""

echo "6. 实际执行 Kafka 消息查看..."
echo "最近的 5 条消息："
echo "----------------------------------------"

# 执行 Kafka 消费者命令查看消息
timeout 10s docker exec kafka kafka-console-consumer \
  --topic user-events \
  --bootstrap-server localhost:9092 \
  --from-beginning \
  --max-messages 5 2>/dev/null || echo "超时或无消息"

echo ""
echo "----------------------------------------"

echo ""
echo "7. 检查 Topic 信息..."
echo "Topic 详细信息："
docker exec kafka kafka-topics \
  --describe \
  --topic user-events \
  --bootstrap-server localhost:9092

echo ""
echo "8. 检查 Consumer Group 状态..."
echo "Consumer Group 信息："
docker exec kafka kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --group user-group \
  --describe 2>/dev/null || echo "Consumer Group 不存在或无活动消费者"

echo ""
echo "=== 验证完成 ==="
echo ""
echo "总结："
echo "✅ 应用日志：查看生产和消费的消息内容"
echo "✅ Kafka UI：直观查看 Topic 中的消息"
echo "✅ Kafka 命令行：直接从 Topic 读取消息"
echo "⚠️  Jaeger 追踪：可能不包含完整消息体（技术限制）"
echo ""
echo "如果您在 Jaeger 中看不到消息体内容，这是正常的，因为："
echo "1. OpenTelemetry 的 Kafka 消息体捕获仍是实验性功能"
echo "2. Spring Boot 3.x 的完整支持还在开发中"
echo "3. 消息体捕获受到大小和配置限制"
echo ""
echo "推荐使用 Kafka UI 或应用日志来查看完整的消息内容。"
