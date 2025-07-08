# 快速开始指南

## 📋 项目概述

这是一个集成了 [Hypertrace Java Agent](https://github.com/hypertrace/javaagent) 的 Spring Boot 演示项目，展示了如何进行：

- **分布式追踪监控**：使用 Hypertrace 和 OpenTelemetry
- **API 性能监控**：捕获 HTTP 请求/响应数据
- **应用指标收集**：使用 Prometheus 和 Grafana 可视化

## 🛠️ 环境要求

- **Java 17+**
- **Docker & Docker Compose**
- **curl 和 jq**（用于测试）

## 🚀 快速开始

### 1. 验证项目
```bash
# 运行完整测试
./scripts/quick-test.sh
```

### 2. 简单运行（不使用监控）
```bash
# 直接启动应用
./scripts/run-without-agent.sh
```

### 3. 完整监控运行

**第一步：下载 Hypertrace Agent**
```bash
./scripts/download-agent.sh
```

**第二步：启动监控服务**
```bash
# 启动 Jaeger、Prometheus、Grafana
docker-compose up -d
```

**第三步：运行应用**
```bash
# 使用 Hypertrace Agent 启动
./scripts/run-with-agent.sh
```

**第四步：测试 API**
```bash
# 在新终端中测试
./scripts/test-api.sh
```

## 🔍 访问监控界面

| 服务 | 地址 | 用途 |
|------|------|------|
| **应用** | http://localhost:8080 | Spring Boot 应用 |
| **Jaeger** | http://localhost:16686 | 分布式追踪 |
| **Prometheus** | http://localhost:9090 | 指标收集 |
| **Grafana** | http://localhost:3000 | 可视化仪表板 |
| **H2 Console** | http://localhost:8080/h2-console | 数据库管理 |

## 🧪 测试 API

### 基本 API 测试
```bash
# 获取所有用户
curl http://localhost:8080/api/users

# 创建用户
curl -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"测试用户","email":"test@example.com","phone":"13800138000"}'

# 查看健康状态
curl http://localhost:8080/actuator/health
```

### 验证监控数据

1. **Jaeger 中查看追踪**：
   - 访问 http://localhost:16686
   - 选择服务 `hypertrace-demo`
   - 查看请求追踪详情

2. **Prometheus 中查看指标**：
   - 访问 http://localhost:9090
   - 搜索 `http_server_requests_seconds`

3. **Grafana 创建仪表板**：
   - 访问 http://localhost:3000 (admin/admin)
   - 添加 Prometheus 数据源
   - 创建自定义仪表板

## 🏗️ 项目结构

```
hypertrace-demo/
├── src/main/java/com/example/hypertracedemo/
│   ├── HypertraceApplication.java          # 主应用
│   ├── controller/UserController.java      # REST API
│   ├── model/User.java                     # 数据模型
│   ├── repository/UserRepository.java     # 数据访问
│   └── service/UserService.java           # 业务逻辑
├── src/main/resources/
│   ├── application.yml                     # 应用配置
│   ├── application-dev.yml                 # 开发环境配置
│   └── import.sql                         # 初始数据
├── scripts/
│   ├── download-agent.sh                  # 下载 Agent
│   ├── run-with-agent.sh                  # 使用 Agent 运行
│   ├── run-without-agent.sh               # 直接运行
│   ├── test-api.sh                        # 测试 API
│   └── quick-test.sh                      # 快速测试
├── docker-compose.yml                     # 监控服务
├── hypertrace-config.yaml                # Agent 配置
└── README.md                              # 详细文档
```

## 📊 监控功能

### Hypertrace Agent 功能
- ✅ 捕获 HTTP 请求/响应头
- ✅ 捕获请求/响应体数据
- ✅ 自动生成分布式追踪
- ✅ 集成 OpenTelemetry 标准

### 监控指标
- 📈 HTTP 请求耗时
- 📈 请求成功率
- 📈 错误率统计
- 📈 JVM 性能指标

## 🔧 配置说明

### Hypertrace 配置 (`hypertrace-config.yaml`)
```yaml
# 数据捕获设置
data-capture:
  request-body:
    enabled: true
    max-size: 1024
  response-body:
    enabled: true
    max-size: 1024
  request-headers:
    enabled: true
  response-headers:
    enabled: true

# 导出端点
reporting:
  endpoint: http://localhost:4317
  secure: false
```

### 应用配置 (`application.yml`)
```yaml
# 监控端点
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
```

## 💡 使用技巧

1. **开发阶段**：使用 `./scripts/run-without-agent.sh` 快速启动
2. **测试阶段**：使用 `./scripts/quick-test.sh` 验证功能
3. **监控阶段**：使用 `./scripts/run-with-agent.sh` 完整监控
4. **API 测试**：使用 `./scripts/test-api.sh` 生成测试数据

## 🚨 常见问题

**Q: Agent 下载失败？**
```bash
# 检查网络连接
curl -I https://github.com/hypertrace/javaagent/releases/latest

# 手动下载
mkdir -p agents
curl -L https://github.com/hypertrace/javaagent/releases/download/1.3.24/hypertrace-agent-1.3.24-all.jar -o agents/hypertrace-agent.jar
```

**Q: 端口冲突？**
```bash
# 检查端口占用
lsof -i :8080
lsof -i :16686
```

**Q: 监控数据不显示？**
```bash
# 检查 Docker 服务
docker-compose ps
docker-compose logs jaeger
```

## 📚 更多资源

- [Hypertrace GitHub](https://github.com/hypertrace/javaagent)
- [OpenTelemetry 文档](https://opentelemetry.io/docs/instrumentation/java/)
- [Spring Boot Actuator](https://docs.spring.io/spring-boot/docs/current/reference/html/actuator.html)

---

🎉 **恭喜！您已成功创建了一个完整的 Hypertrace 监控演示项目！**
