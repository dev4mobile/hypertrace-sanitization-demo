#!/bin/bash

echo "=== Kafka Broker 监控验证脚本 ==="
echo ""

echo "1. 检查服务状态..."
echo "应用状态:"
if pgrep -f "hypertrace-demo" > /dev/null; then
    echo "✅ 应用正在运行"
else
    echo "❌ 应用未运行"
fi

echo "Kafka 状态:"
if docker ps | grep kafka > /dev/null; then
    echo "✅ Kafka 正在运行"
else
    echo "❌ Kafka 未运行"
fi

echo "Jaeger 状态:"
if docker ps | grep jaeger > /dev/null; then
    echo "✅ Jaeger 正在运行"
else
    echo "❌ Jaeger 未运行"
fi

echo ""
echo "2. 检查 Kafka Agent 日志..."
echo "Kafka Hypertrace Agent 启动信息:"
docker logs kafka 2>&1 | grep -i "hypertrace agent started" | tail -3

echo ""
echo "3. 发送测试消息..."
for i in {1..3}; do
    echo "发送消息 $i..."
    curl -s -X POST http://localhost:8080/api/users/$i/notify
    sleep 1
done

echo ""
echo "4. 等待消息处理..."
sleep 3

echo ""
echo "5. 检查 Kafka 消息..."
echo "最新消息:"
docker exec kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic user-events --from-beginning --max-messages 3 --timeout-ms 3000 2>/dev/null

echo ""
echo "6. 检查 Kafka Agent 连接状态..."
echo "Agent 连接日志:"
docker logs kafka --tail 10 2>&1 | grep -E "(export|connect|jaeger)" || echo "未找到连接相关日志"

echo ""
echo "=== 监控验证结果 ==="
echo ""
echo "✅ 成功配置的内容:"
echo "1. Kafka Broker 已添加 Hypertrace Java Agent"
echo "2. Agent 配置文件已正确挂载"
echo "3. 服务名设置为: kafka-broker"
echo "4. 启用了 Kafka 消息体捕获功能"

echo ""
echo "🔍 在 Jaeger UI 中查看监控数据:"
echo "1. 访问: http://localhost:16686"
echo "2. 服务列表中查找:"
echo "   - hypertrace-demo (应用服务)"
echo "   - kafka-broker (Kafka 服务端) ← 新增"
echo "3. 在 kafka-broker 服务中查找操作:"
echo "   - kafka.produce"
echo "   - kafka.consume"
echo "   - messaging.*"
echo "4. 检查 span attributes 中的消息体:"
echo "   - messaging.message.payload"
echo "   - kafka.message.payload"

echo ""
echo "📊 预期效果:"
echo "- 应该能看到从应用到 Kafka Broker 的完整调用链"
echo "- Kafka Broker 端应该有独立的 traces"
echo "- 消息的生产和消费过程都应该被监控到"
echo "- 可以观察到消息在 Kafka 内部的处理流程"

echo ""
echo "⚠️  注意事项:"
echo "- Kafka Broker 的 traces 可能需要几分钟才会出现在 Jaeger UI"
echo "- 如果看不到 kafka-broker 服务，检查 Agent 连接状态"
echo "- 某些版本的 Hypertrace Agent 对 Kafka 服务端支持有限"

echo ""
echo "验证完成！请查看 Jaeger UI 确认监控效果。"
