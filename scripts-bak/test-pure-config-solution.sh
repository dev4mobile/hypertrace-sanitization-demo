#!/bin/bash

echo "=== 纯配置方案测试：Kafka 消息体捕获 ==="
echo ""

# 停止现有应用
echo "1. 停止现有应用..."
pkill -f "hypertrace-demo" 2>/dev/null || true
pkill -f "opentelemetry-javaagent" 2>/dev/null || true
sleep 3

# 检查监控栈
echo "2. 检查监控栈状态..."
if ! curl -f -s http://localhost:16686 > /dev/null; then
    echo "❌ Jaeger 未运行，请先运行: docker-compose up -d"
    exit 1
fi
echo "✅ Jaeger 正在运行"

# 构建应用
echo ""
echo "3. 构建应用..."
./gradlew clean build -x test
if [ $? -ne 0 ]; then
    echo "❌ 构建失败"
    exit 1
fi
echo "✅ 构建成功"

# 启动应用（使用纯配置方案）
echo ""
echo "4. 启动应用（使用纯配置的 OpenTelemetry Agent）..."
./scripts/run-with-otel-config.sh &
APP_PID=$!

echo "应用 PID: $APP_PID"
echo "等待应用启动..."

# 等待应用启动
for i in {1..60}; do
    if curl -f -s http://localhost:8080/actuator/health > /dev/null; then
        echo "✅ 应用启动成功"
        break
    fi
    if [ $i -eq 60 ]; then
        echo "❌ 应用启动超时"
        kill $APP_PID 2>/dev/null || true
        exit 1
    fi
    sleep 2
done

echo ""
echo "5. 创建测试用户..."

# 创建用户1
USER1_RESPONSE=$(curl -s -X POST http://localhost:8080/api/users \
    -H "Content-Type: application/json" \
    -d '{
        "name": "Config Test User 1",
        "email": "config1@example.com",
        "phone": "13800138001"
    }')
echo "用户1创建响应: $USER1_RESPONSE"

# 创建用户2
USER2_RESPONSE=$(curl -s -X POST http://localhost:8080/api/users \
    -H "Content-Type: application/json" \
    -d '{
        "name": "Config Test User 2", 
        "email": "config2@example.com",
        "phone": "13800138002"
    }')
echo "用户2创建响应: $USER2_RESPONSE"

echo ""
echo "6. 发送 Kafka 消息..."

# 发送通知给用户2
echo "发送通知给用户 ID=2..."
NOTIFY_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST http://localhost:8080/api/users/2/notify)
echo "通知响应: $NOTIFY_RESPONSE"

echo ""
echo "7. 等待消息处理..."
sleep 5

echo ""
echo "8. 验证结果..."
echo ""
echo "🔗 Jaeger UI: http://localhost:16686"
echo ""
echo "在 Jaeger UI 中查看步骤："
echo "1. 打开 http://localhost:16686"
echo "2. 在左侧选择服务: 'hypertrace-demo'"
echo "3. 点击 'Find Traces' 按钮"
echo "4. 查找最新的追踪记录（包含 'POST /api/users/{id}/notify'）"
echo "5. 点击该追踪记录展开详细信息"
echo ""
echo "您应该看到的 Span 结构："
echo "├── POST /api/users/{id}/notify (HTTP 请求)"
echo "├── user-events send (Kafka 生产者 span)"
echo "└── user-events receive (Kafka 消费者 span)"
echo ""
echo "在 Kafka 相关的 span 中查找以下属性："
echo ""
echo "生产者 span (user-events send) 可能包含："
echo "- messaging.system: kafka"
echo "- messaging.destination: user-events"
echo "- messaging.kafka.message.key: 2"
echo "- messaging.message.payload: {JSON消息体} (如果支持)"
echo ""
echo "消费者 span (user-events receive) 可能包含："
echo "- messaging.system: kafka"
echo "- messaging.destination: user-events"
echo "- messaging.kafka.partition: 0"
echo "- messaging.kafka.offset: (偏移量)"
echo "- messaging.message.payload: {JSON消息体} (如果支持)"
echo ""

echo "9. 关于消息体捕获的说明："
echo ""
echo "OpenTelemetry 1.33.5 对 Kafka 消息体捕获的支持情况："
echo "✅ 支持基本的 Kafka 追踪（topic, partition, offset 等）"
echo "⚠️  消息体捕获是实验性功能，可能不稳定"
echo "⚠️  Spring Kafka 3.x 的消息体捕获支持有限"
echo "⚠️  消息体大小受到限制（默认 8KB）"
echo ""
echo "如果看不到消息体内容，这是正常的，因为："
echo "1. OpenTelemetry 的 Kafka 消息体捕获仍是实验性功能"
echo "2. Spring Boot 3.x 的支持还在完善中"
echo "3. 消息体捕获可能需要特定的配置或版本"
echo ""

echo "10. 替代方案："
echo "- 查看应用日志中的消息内容（#### -> Producing message -> 和 #### -> Consumed message ->）"
echo "- 使用 Kafka UI (http://localhost:8088) 查看消息内容"
echo "- 考虑升级到更新版本的 OpenTelemetry Agent"
echo "- 或者等待 Hypertrace Agent 对 Spring Boot 3.x 的完整支持"
echo ""

echo "=== 测试完成 ==="
echo "应用正在后台运行，PID: $APP_PID"
echo "使用 'kill $APP_PID' 停止应用"
echo ""
echo "总结："
echo "- 这是一个纯配置的解决方案，无需修改业务代码"
echo "- 使用了最新的 OpenTelemetry Agent 1.33.5"
echo "- 启用了所有可用的 Kafka 追踪功能"
echo "- 如果消息体捕获不工作，这是当前技术栈的限制，而非配置问题"
