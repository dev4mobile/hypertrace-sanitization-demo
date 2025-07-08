# Hypertrace Java Agent Spring Boot Demo

这是一个使用 [Hypertrace Java Agent](https://github.com/hypertrace/javaagent) 监控 Spring Boot Web 应用的演示项目。

## 项目简介

本项目展示了如何使用 Hypertrace Java Agent 来监控 Spring Boot 应用，包括：

- 📊 **分布式追踪**: 使用 OpenTelemetry 和 Hypertrace 进行请求追踪
- 📈 **应用监控**: 收集应用性能指标和运行状态
- 🔍 **请求分析**: 捕获 HTTP 请求和响应的头部、体部信息
- 🖥️ **可视化界面**: 使用 Jaeger、Prometheus 和 Grafana 进行数据可视化

## 技术栈

- **Java 17**: 应用运行时
- **Spring Boot 3.2**: Web 应用框架
- **Gradle**: 构建工具
- **H2 Database**: 内存数据库
- **Apache Kafka**: 分布式流处理平台
- **Hypertrace Java Agent**: 分布式追踪代理
- **Docker Compose**: 容器化部署监控服务

## 项目结构

```
hypertrace-demo/
├── src/main/java/com/example/hypertracedemo/
│   ├── HypertraceApplication.java          # 主应用类
│   ├── controller/UserController.java      # REST API 控制器
│   ├── model/User.java                     # 用户实体类
│   ├── repository/UserRepository.java     # 数据访问层
│   └── service/UserService.java           # 业务逻辑层
├── src/main/resources/
│   ├── application.yml                     # 应用配置
│   ├── application-dev.yml                 # 开发环境配置
│   └── import.sql                         # 初始化数据
├── scripts/
│   ├── download-agent.sh                  # 下载 Hypertrace Agent
│   ├── run-with-agent.sh                  # 运行应用
│   ├── test-api.sh                        # 测试 API
│   ├── kafka-topics.sh                    # Kafka Topic 管理
│   ├── kafka-test.sh                      # Kafka 生产者/消费者测试
│   └── start-monitoring-stack.sh          # 启动完整监控栈
├── agents/                                # Agent 存放目录
├── docker-compose.yml                     # 监控服务编排
├── hypertrace-config.yaml                # Hypertrace 配置
└── README.md                              # 项目说明
```

## 快速开始

### 1. 环境准备

确保您的系统已安装：

- Java 17+
- Docker 和 Docker Compose
- curl 和 jq（用于测试脚本）

### 2. 下载 Hypertrace Agent

```bash
# 给脚本添加执行权限
chmod +x scripts/*.sh

# 下载最新版本的 Hypertrace Java Agent
./scripts/download-agent.sh
```

### 3. 启动监控服务和 Kafka

```bash
# 方式一: 使用便捷脚本启动完整监控栈（推荐）
./scripts/start-monitoring-stack.sh

# 方式二: 手动启动服务
docker-compose up -d

# 检查服务状态
docker-compose ps
```

### 4. 构建和运行应用

```bash
# 使用 Hypertrace Agent 运行应用
./scripts/run-with-agent.sh
```

### 5. 测试 API

```bash
# 在另一个终端运行测试脚本
./scripts/test-api.sh
```

## API 接口

应用提供以下 REST API 接口：

| 方法 | 路径 | 描述 |
|------|------|------|
| GET | `/api/users` | 获取所有用户 |
| GET | `/api/users/{id}` | 根据 ID 获取用户 |
| POST | `/api/users` | 创建新用户 |
| PUT | `/api/users/{id}` | 更新用户信息 |
| DELETE | `/api/users/{id}` | 删除用户 |

### 示例请求

```bash
# 获取所有用户
curl -X GET http://localhost:8080/api/users

# 创建新用户
curl -X POST http://localhost:8080/api/users \
     -H "Content-Type: application/json" \
     -d '{
       "name": "新用户",
       "email": "newuser@example.com",
       "phone": "13800138000"
     }'

# 获取特定用户
curl -X GET http://localhost:8080/api/users/1
```

## Kafka 功能

本项目集成了 Apache Kafka 用于演示消息队列监控。Kafka 与 Hypertrace 的集成允许您监控消息的生产、消费和流处理过程。

### Kafka 服务信息

- **Kafka Broker**: localhost:9092
- **Zookeeper**: localhost:2181
- **Kafka UI**: http://localhost:8080

### Topic 管理

使用 `kafka-topics.sh` 脚本管理 Kafka Topics：

```bash
# 创建新的 Topic
./scripts/kafka-topics.sh create user-events

# 列出所有 Topics
./scripts/kafka-topics.sh list

# 查看 Topic 详情
./scripts/kafka-topics.sh describe user-events

# 删除 Topic
./scripts/kafka-topics.sh delete user-events
```

### 消息测试

使用 `kafka-test.sh` 脚本测试消息生产和消费：

```bash
# 发送测试消息
./scripts/kafka-test.sh test-messages user-events

# 启动消费者（在新终端窗口）
./scripts/kafka-test.sh consumer user-events

# 启动生产者（交互式）
./scripts/kafka-test.sh producer user-events

# 查看 Consumer Groups
./scripts/kafka-test.sh groups

# 描述 Consumer Group
./scripts/kafka-test.sh describe-group console-consumer-12345
```

### Kafka 监控特性

通过 Hypertrace 和 OpenTelemetry，您可以监控：

1. **消息追踪**: 每条消息的端到端追踪
2. **生产者指标**: 发送速率、延迟、错误率
3. **消费者指标**: 消费速率、偏移量滞后、处理时间
4. **Broker 指标**: 吞吐量、存储、网络 I/O
5. **分布式追踪**: 跨服务的消息流追踪

### JMX Exporter 初始化

Kafka 的 JMX 指标通过 Prometheus JMX Exporter 采集。首次启动前请执行：

```bash
# 下载 JMX Exporter 及配置文件
./scripts/download-jmx-exporter.sh
```

该脚本会在 agents/ 目录下下载 jmx_prometheus_javaagent.jar 和 kafka-2_0_0.yml。

docker-compose.yml 已自动挂载到 Kafka 容器，Prometheus 会自动采集相关指标。

如需自定义 JMX 采集规则，可编辑 agents/kafka-2_0_0.yml。

### Kafka 与应用集成示例

在 Spring Boot 应用中集成 Kafka：

```java
@Component
public class UserEventProducer {

    @Autowired
    private KafkaTemplate<String, String> kafkaTemplate;

    public void sendUserCreatedEvent(User user) {
        String message = String.format(
            "{\"event\": \"user_created\", \"userId\": %d, \"timestamp\": \"%s\"}",
            user.getId(), Instant.now()
        );
        kafkaTemplate.send("user-events", message);
    }
}

@Component
public class UserEventConsumer {

    @KafkaListener(topics = "user-events", groupId = "user-service")
    public void handleUserEvent(String message) {
        // 处理用户事件
        System.out.println("Received user event: " + message);
    }
}
```

### JMX 指标监控

Kafka 提供丰富的 JMX 指标，通过 Prometheus 收集：

- `kafka.server:type=BrokerTopicMetrics` - Topic 级别指标
- `kafka.server:type=ReplicaManager` - 副本管理指标
- `kafka.controller:type=KafkaController` - 控制器指标
- `kafka.network:type=RequestMetrics` - 网络请求指标

这些指标在 Grafana 中可以创建丰富的监控仪表板。

## 监控界面

应用运行后，您可以访问以下监控界面：

### Jaeger UI (分布式追踪)
- 地址: http://localhost:16686
- 功能: 查看请求追踪、服务拓扑、性能分析

### Prometheus (指标收集)
- 地址: http://localhost:9090
- 功能: 查看应用指标、设置告警规则

### Grafana (可视化仪表板)
- 地址: http://localhost:3000
- 登录: admin/admin
- 功能: 创建仪表板、数据可视化

### Kafka UI (Kafka 管理界面)
- 地址: http://localhost:8088
- 功能: 管理 Topics、查看 Consumer Groups、监控 Kafka 集群

### H2 Database Console
- 地址: http://localhost:8080/h2-console
- JDBC URL: `jdbc:h2:mem:testdb`
- 用户名: `sa`
- 密码: `password`

### Spring Boot Actuator
- 健康检查: http://localhost:8080/actuator/health
- 应用指标: http://localhost:8080/actuator/metrics
- 应用信息: http://localhost:8080/actuator/info

## Hypertrace 配置

Hypertrace Agent 的配置文件是 `hypertrace-config.yaml`，主要配置项：

```yaml
# 数据捕获配置
data-capture:
  request-body:
    enabled: true      # 捕获请求体
    max-size: 1024     # 最大捕获大小
  response-body:
    enabled: true      # 捕获响应体
    max-size: 1024
  request-headers:
    enabled: true      # 捕获请求头
  response-headers:
    enabled: true      # 捕获响应头

# 导出配置
reporting:
  endpoint: http://localhost:4317  # OTLP 端点
  secure: false                    # 是否使用 TLS
```

## 开发说明

### 添加自定义追踪

您可以在代码中添加自定义的追踪信息：

```java
import io.opentelemetry.api.trace.Tracer;
import io.opentelemetry.api.trace.Span;

@Service
public class UserService {

    public User processUser(User user) {
        Span span = tracer.spanBuilder("process-user")
            .setAttribute("user.id", user.getId())
            .setAttribute("user.name", user.getName())
            .startSpan();

        try {
            // 业务逻辑处理
            return doProcess(user);
        } finally {
            span.end();
        }
    }
}
```

### 添加自定义指标

```java
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Counter;

@Service
public class UserService {

    private final Counter userCreatedCounter;

    public UserService(MeterRegistry meterRegistry) {
        this.userCreatedCounter = Counter.builder("users.created")
            .description("Number of users created")
            .register(meterRegistry);
    }

    public User createUser(User user) {
        User savedUser = userRepository.save(user);
        userCreatedCounter.increment();
        return savedUser;
    }
}
```

## 故障排除

### 常见问题

1. **Agent 下载失败**
   ```bash
   # 检查网络连接
   curl -I https://github.com/hypertrace/javaagent/releases/latest

   # 手动下载
   wget https://github.com/hypertrace/javaagent/releases/download/1.3.24/hypertrace-agent-1.3.24-all.jar
   ```

2. **应用启动失败**
   ```bash
   # 检查 Java 版本
   java -version

   # 检查端口占用
   lsof -i :8080
   ```

3. **监控数据不显示**
   ```bash
   # 检查 Docker 服务状态
   docker-compose ps

   # 查看服务日志
   docker-compose logs jaeger
   ```

### 调试模式

启用调试模式查看详细日志：

```bash
# 设置调试级别
export OTEL_LOG_LEVEL=debug

# 启用 Agent 调试
java -javaagent:agents/hypertrace-agent.jar \
     -Dotel.javaagent.debug=true \
     -jar build/libs/hypertrace-demo-0.0.1-SNAPSHOT.jar
```

## 扩展功能

### 自定义过滤器

您可以实现自定义的请求过滤器：

```java
import org.hypertrace.agent.filter.FilterProvider;
import org.hypertrace.agent.filter.Filter;

public class CustomFilterProvider implements FilterProvider {

    @Override
    public Filter getFilter() {
        return new CustomFilter();
    }
}
```

### 数据库支持

如需使用其他数据库，修改 `build.gradle.kts` 和 `application.yml`：

```kotlin
// build.gradle.kts
dependencies {
    implementation("org.postgresql:postgresql")
    // 或者 implementation("mysql:mysql-connector-java")
}
```

```yaml
# application.yml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/hypertrace_demo
    username: postgres
    password: password
    driver-class-name: org.postgresql.Driver
```

## 参考资料

- [Hypertrace Java Agent GitHub](https://github.com/hypertrace/javaagent)
- [OpenTelemetry Java 文档](https://opentelemetry.io/docs/instrumentation/java/)
- [Spring Boot Actuator 文档](https://docs.spring.io/spring-boot/docs/current/reference/html/actuator.html)
- [Jaeger 文档](https://www.jaegertracing.io/docs/)
- [Prometheus 文档](https://prometheus.io/docs/)
- [Grafana 文档](https://grafana.com/docs/)

## 许可证

本项目采用 MIT 许可证，详情请参阅 [LICENSE](LICENSE) 文件。

## Kafka 集成与分布式追踪测试

本项目已集成 Kafka，用于模拟用户事件通知。当调用特定 API 时，应用会向 Kafka 主题发送消息，并由消费者服务处理。Hypertrace Agent 会自动捕获从 HTTP 请求到 Kafka 生产和消费的完整分布式链路。

### 测试步骤

1.  **启动完整的监控栈**

    请确保所有服务（包括 Kafka）都已启动：

    ```bash
    ./scripts/start-monitoring-stack.sh
    ```

2.  **创建测试用户**

    使用 `curl` 创建一个新用户。请记下返回的用户 `id`。

    ```bash
    curl -X POST http://localhost:8080/api/users \
    -H "Content-Type: application/json" \
    -d '{"name": "kafka-user", "email": "kafka@example.com"}'
    ```

    假设返回的 id 是 `1`。

3.  **触发 Kafka 通知**

    调用 `/notify` 端点，这将触发向 `user-events` 主题发送一条消息。

    ```bash
    curl -X POST http://localhost:8080/api/users/1/notify
    ```

4.  **在 Jaeger 中观测追踪数据**

    - 打开 Jaeger UI：[http://localhost:16686](http://localhost:16686)
    - 在服务列表中选择 `hypertrace-demo-app`。
    - 点击 "Find Traces"。
    - 你应该能看到一条名为 `POST /api/users/{id}/notify` 的新追踪记录。

    点击该记录，你将看到一个包含多个 Span 的分布式链路：
    -   `POST /api/users/{id}/notify`：根 Span，代表整个 HTTP 请求。
    -   `user-events send`：子 Span，代表 Kafka 生产者向 Topic 发送消息。
    -   `user-events receive`：另一个子 Span，代表 Kafka 消费者从 Topic 接收并处理消息。

    这个视图清晰地展示了 Hypertrace 如何跨服务和消息队列追踪请求。

5.  **(可选) 在 Kafka UI 中验证消息**

    - 打开 Kafka UI：[http://localhost:8088](http://localhost:8088)
    - 导航到 `user-events` 主题，你应该能看到刚刚发送的消息内容。
