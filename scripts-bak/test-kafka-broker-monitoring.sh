#!/bin/bash

echo "=== Kafka Broker 监控测试脚本 ==="
echo ""

echo "1. 重启 Kafka 并启用 Hypertrace Agent..."
./scripts/restart-kafka-with-agent.sh

echo ""
echo "2. 等待系统稳定..."
sleep 10

echo ""
echo "3. 启动应用..."
pkill -f "hypertrace-demo" 2>/dev/null || true
sleep 3
./scripts/run-with-compatible-agent.sh &
APP_PID=$!

echo ""
echo "4. 等待应用启动..."
sleep 20

echo ""
echo "5. 测试消息发送..."
echo "发送测试消息到 Kafka..."
for i in {1..3}; do
    echo "发送第 $i 条消息..."
    curl -s -X POST http://localhost:8080/api/users/$i/notify
    sleep 2
done

echo ""
echo "6. 等待消息处理..."
sleep 5

echo ""
echo "7. 检查 Kafka 消息..."
echo "最近的消息内容:"
docker exec kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic user-events --from-beginning --max-messages 3 --timeout-ms 5000

echo ""
echo "8. 检查监控状态..."
echo "=== 监控检查结果 ==="

# 检查应用状态
if pgrep -f "hypertrace-demo" > /dev/null; then
    echo "✅ 应用正在运行"
else
    echo "❌ 应用未运行"
fi

# 检查 Kafka 状态
if docker ps | grep kafka > /dev/null; then
    echo "✅ Kafka 正在运行"
else
    echo "❌ Kafka 未运行"
fi

# 检查 Jaeger 状态
if docker ps | grep jaeger > /dev/null; then
    echo "✅ Jaeger 正在运行"
else
    echo "❌ Jaeger 未运行"
fi

echo ""
echo "=== 在 Jaeger UI 中查看监控数据 ==="
echo "1. 访问 Jaeger UI: http://localhost:16686"
echo "2. 在服务列表中查找以下服务:"
echo "   - hypertrace-demo (应用服务)"
echo "   - kafka-broker (Kafka 服务端)"
echo "3. 在 kafka-broker 服务中查找以下操作:"
echo "   - kafka.produce (消息生产)"
echo "   - kafka.consume (消息消费)"
echo "   - messaging.* (消息处理)"
echo "4. 检查 span 的 attributes 中是否包含:"
echo "   - messaging.message.payload (消息体)"
echo "   - kafka.message.payload (Kafka 消息体)"
echo "   - messaging.destination.name (主题名)"
echo "   - messaging.kafka.partition (分区信息)"

echo ""
echo "=== 预期结果 ==="
echo "✅ 应该能在 Jaeger UI 中看到:"
echo "   1. hypertrace-demo 服务的 HTTP 请求 traces"
echo "   2. kafka-broker 服务的消息处理 traces"
echo "   3. 两个服务之间的分布式追踪链路"
echo "   4. Kafka 消息的完整生命周期"

echo ""
echo "=== 故障排除 ==="
echo "如果看不到 kafka-broker 服务的 traces:"
echo "1. 检查 Kafka 日志: docker logs kafka"
echo "2. 检查 Hypertrace Agent 是否正确加载"
echo "3. 确认 Kafka 配置文件路径正确"
echo "4. 检查网络连接到 Jaeger"

echo ""
echo "测试完成！请查看 Jaeger UI 验证监控效果。"
