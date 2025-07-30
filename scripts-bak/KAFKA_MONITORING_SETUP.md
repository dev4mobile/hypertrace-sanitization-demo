# Kafka Broker Hypertrace 监控配置

## 概述

本文档描述了如何为 Kafka Broker 添加 Hypertrace Java Agent 来观测 Kafka 服务端的数据处理过程。

## 已完成的配置

### 1. 创建的配置文件

- **`hypertrace-config-kafka.yaml`** - ~~Kafka Broker 专用的 Hypertrace 配置~~ (已移除)
- **`hypertrace-config-compatible.yaml`** - 应用端兼容配置
- **`scripts/restart-kafka-with-agent.sh`** - Kafka 重启脚本
- **`scripts/verify-kafka-monitoring.sh`** - 监控验证脚本

### 2. Docker Compose 配置

修改了 `docker-compose.yml` 中的 Kafka 服务：

```yaml
kafka:
  image: confluentinc/cp-kafka:7.4.4
  environment:
    KAFKA_OPTS: >-
      -javaagent:/opt/hypertrace/hypertrace-agent.jar
      -Dhypertrace.service.name=kafka-broker
      -Dotel.instrumentation.kafka.enabled=true
      -Dotel.instrumentation.messaging.enabled=true
      -Dotel.instrumentation.messaging.experimental.capture-payload.enabled=true
      -Dotel.instrumentation.kafka.experimental.capture-payload.enabled=true
      -Dotel.traces.sampler=always_on
      -Dotel.metrics.exporter=none
  volumes:
    - ./agents/hypertrace-agent.jar:/opt/hypertrace/hypertrace-agent.jar:ro
```

### 3. 监控服务

现在系统中有两个被监控的服务：

1. **`hypertrace-demo`** - Spring Boot 应用
   - 监控 HTTP 请求
   - 监控 Kafka 客户端（Producer/Consumer）
   - 监控数据库操作

2. **`kafka-broker`** - Kafka 服务端
   - 监控消息接收和处理
   - 监控日志写入操作
   - 监控网络通信

## 监控数据查看

### 在 Jaeger UI 中查看

1. 访问：http://localhost:16686
2. 服务列表中查找：
   - `hypertrace-demo` (应用服务)
   - `kafka-broker` (Kafka 服务端)

### 预期的 Traces

1. **完整调用链**：
   ```
   HTTP Request → Application → Kafka Producer → Kafka Broker
   ```

2. **Kafka Broker Spans**：
   - `kafka.produce` - 消息生产
   - `kafka.consume` - 消息消费
   - `messaging.*` - 消息处理

3. **消息体数据**（在 span attributes 中）：
   - `messaging.message.payload`
   - `kafka.message.payload`
   - `messaging.destination.name`
   - `messaging.kafka.partition`

## 使用脚本

### 重启 Kafka 并启用监控
```bash
./scripts/restart-kafka-with-agent.sh
```

### 验证监控配置
```bash
./scripts/verify-kafka-monitoring.sh
```

### 启动应用（兼容配置）
```bash
./scripts/run-with-compatible-agent.sh
```

### 测试消息发送
```bash
curl -X POST http://localhost:8080/api/users/1/notify
```

## 配置特点

### Kafka Broker 配置亮点

1. **服务端监控**：直接在 Kafka Broker 内部监控消息处理
2. **消息体捕获**：可以观察到完整的消息内容
3. **网络通信监控**：监控客户端与服务端的通信
4. **分布式追踪**：与应用端形成完整的调用链

### 技术实现

1. **Agent 挂载**：通过 Docker volume 挂载 Hypertrace Agent
2. **配置文件**：使用专门的 Kafka 配置文件
3. **环境变量**：通过 KAFKA_OPTS 传递 Agent 参数
4. **网络通信**：使用容器网络连接到 Jaeger

## 故障排除

### 如果看不到 kafka-broker 服务

1. **检查 Agent 启动**：
   ```bash
   docker logs kafka | grep "hypertrace agent started"
   ```

2. **检查配置文件**：
   ```bash
   # hypertrace-config-kafka.yaml 文件已移除，不再需要检查
   docker exec kafka env | grep KAFKA_OPTS
   ```

3. **检查网络连接**：
   ```bash
   docker exec kafka nc -z jaeger 4317
   ```

### 常见问题

1. **连接问题**：确保使用容器网络地址 `jaeger:4317`
2. **配置冲突**：避免环境变量覆盖配置文件
3. **版本兼容**：Hypertrace Agent 1.3.24 对新版本支持有限

## 监控效果

通过这个配置，你可以：

1. **观察完整的消息流**：从应用发送到 Kafka 接收的全过程
2. **分析性能瓶颈**：查看消息在各个环节的耗时
3. **调试问题**：通过 traces 快速定位问题所在
4. **监控消息内容**：在开发环境中查看实际的消息体

## 安全注意事项

- 消息体捕获可能包含敏感信息，生产环境请谨慎启用
- 建议在生产环境中禁用消息体捕获或进行脱敏处理
- 监控数据会增加系统开销，请根据需要调整采样率

## 下一步

- 考虑升级到最新版本的 Hypertrace Agent
- 添加更多的监控指标和告警
- 集成 Prometheus 和 Grafana 进行指标监控
