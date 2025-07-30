#!/bin/bash

echo "=== Kafka 监控诊断脚本 ==="
echo ""

echo "1. 检查应用状态..."
if pgrep -f "hypertrace-demo" > /dev/null; then
    echo "✓ 应用正在运行"
    ps aux | grep java | grep hypertrace | head -1
else
    echo "✗ 应用未运行"
fi

echo ""
echo "2. 检查 Kafka 状态..."
if docker ps | grep kafka > /dev/null; then
    echo "✓ Kafka 正在运行"
else
    echo "✗ Kafka 未运行"
fi

echo ""
echo "3. 检查 Jaeger 状态..."
if docker ps | grep jaeger > /dev/null; then
    echo "✓ Jaeger 正在运行"
    echo "Jaeger UI: http://localhost:16686"
else
    echo "✗ Jaeger 未运行"
fi

echo ""
echo "4. 检查 Kafka 主题..."
if ./scripts/kafka-topics.sh list | grep user-events > /dev/null; then
    echo "✓ user-events 主题存在"
else
    echo "✗ user-events 主题不存在"
fi

echo ""
echo "5. 测试 API 调用..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/users/1/notify)
if [ "$RESPONSE" = "200" ]; then
    echo "✓ API 调用成功 (HTTP $RESPONSE)"
else
    echo "✗ API 调用失败 (HTTP $RESPONSE)"
fi

echo ""
echo "6. 检查 Kafka 消息..."
echo "请运行以下命令检查 Kafka 消息："
echo "docker exec -it kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic user-events --from-beginning --max-messages 1"

echo ""
echo "7. 在 Jaeger UI 中查找："
echo "- 服务名: hypertrace-demo"
echo "- 查找包含 'kafka' 或 'messaging' 的 span"
echo "- 检查 span 的 attributes/tags 中是否有："
echo "  * messaging.message.payload"
echo "  * kafka.message.payload"
echo "  * message.body"

echo ""
echo "8. 可能的问题和解决方案："
echo "a) Hypertrace Agent 版本过旧 (当前: 1.3.24)"
echo "   - 建议升级到最新版本"
echo "b) Spring Boot 3.3.0 兼容性问题"
echo "   - 考虑降级到 Spring Boot 2.7.x"
echo "c) 配置参数不生效"
echo "   - 检查配置文件路径和格式"

echo ""
echo "9. 调试建议："
echo "- 查看应用启动日志中的 Hypertrace 相关信息"
echo "- 检查是否有 Kafka 相关的错误日志"
echo "- 确认消息体大小是否超过配置的 max-size"

echo ""
echo "诊断完成！"
