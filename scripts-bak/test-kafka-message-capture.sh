#!/bin/bash

echo "=== Kafka 消息体捕获测试 ==="
echo "1. 停止当前应用..."
pkill -f "hypertrace-demo"

echo "2. 等待应用停止..."
sleep 5

echo "3. 使用增强配置启动应用..."
./scripts/run-with-enhanced-agent.sh &
APP_PID=$!

echo "4. 等待应用启动..."
sleep 20

echo "5. 测试 API 调用..."
curl -X POST http://localhost:8080/api/users/1/notify -v

echo ""
echo "6. 等待消息处理..."
sleep 5

echo "7. 检查应用日志..."
echo "请查看应用启动日志，寻找以下关键词："
echo "- 'KafkaProducer'"
echo "- 'message-body'"
echo "- 'capture-payload'"
echo "- 'messaging'"

echo ""
echo "8. 在 Jaeger UI 中查找："
echo "- 服务名: hypertrace-demo"
echo "- 操作名: kafka.produce 或 messaging.produce"
echo "- 在 span 的 attributes/tags 中查找："
echo "  * messaging.message.payload"
echo "  * kafka.message.payload"
echo "  * message.body"
echo "  * messaging.payload"

echo ""
echo "9. 如果仍然看不到消息体，请检查："
echo "- Hypertrace Agent 版本是否支持 Spring Kafka 3.x"
echo "- 是否有相关的错误日志"
echo "- 消息体大小是否超过配置的 max-size"

echo ""
echo "测试完成！请检查 Jaeger UI 中的 trace 信息。"
