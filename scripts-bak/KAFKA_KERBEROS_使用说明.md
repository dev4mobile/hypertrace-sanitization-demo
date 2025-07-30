# Kafka Kerberos 认证使用说明

## 概述

本项目已成功为 Kafka 配置了 Kerberos 认证支持，实现了双协议模式：
- **PLAINTEXT** (端口 9092) - 用于开发和测试
- **SASL_PLAINTEXT** (端口 9093) - 使用 Kerberos 认证

## 功能特性

✅ **已完成的功能**：
- Docker Compose 环境中的 Kerberos KDC 服务
- Kafka 双协议支持（PLAINTEXT + SASL_PLAINTEXT）
- 应用程序 Kerberos 认证配置
- 全面的测试和诊断脚本
- 详细的故障排除工具

⚠️ **当前状态**：
- 基本配置已完成，SASL 已启用
- 存在 Zookeeper 连接超时问题，需要进一步调试

## 快速开始

### 1. 启动服务

```bash
# 启动所有服务
docker-compose up -d

# 检查服务状态
docker-compose ps
```

### 2. 验证配置

```bash
# 运行诊断脚本
./scripts/diagnose-kerberos-auth.sh

# 运行完整测试
./scripts/test-kafka-kerberos-auth.sh
```

### 3. 启动应用

```bash
# 使用 Kerberos 认证启动应用
./scripts/run-with-kerberos.sh

# 或使用标准模式启动
./scripts/run-with-agent.sh
```

## 配置说明

### Kafka 配置

- **PLAINTEXT 端口**: 9092
- **SASL_PLAINTEXT 端口**: 9093
- **JMX 端口**: 19092
- **Kerberos 服务名**: kafka
- **SASL 机制**: GSSAPI

### 应用配置

使用 `application-kerberos.yml` 配置文件：

```yaml
spring:
  kafka:
    bootstrap-servers: localhost:9093
    properties:
      security:
        protocol: SASL_PLAINTEXT
      sasl:
        mechanism: GSSAPI
        kerberos:
          service:
            name: kafka
```

### Kerberos 配置

- **Realm**: EXAMPLE.COM
- **KDC**: kdc.example.com
- **Kafka 服务主体**: kafka/kafka.example.com@EXAMPLE.COM
- **客户端主体**: kafka-client@EXAMPLE.COM

## 测试和验证

### 可用的脚本

1. **测试脚本**: `./scripts/test-kafka-kerberos-auth.sh`
   - 全面的功能测试
   - 环境检查
   - 连接测试
   - 消息发送接收测试

2. **诊断脚本**: `./scripts/diagnose-kerberos-auth.sh`
   - 系统环境检查
   - 配置文件验证
   - 服务状态检查
   - 网络连接测试

3. **运行脚本**: `./scripts/run-with-kerberos.sh`
   - 启用 Kerberos 认证的应用启动
   - 包含所有必要的 JVM 参数

### 手动测试命令

```bash
# 检查端口连接
nc -z localhost 88    # KDC
nc -z localhost 9092  # Kafka PLAINTEXT
nc -z localhost 9093  # Kafka SASL_PLAINTEXT

# 验证 Keytab 文件
klist -kt kerberos/kafka-client.keytab

# 获取 Kerberos 票据
kinit -kt kerberos/kafka-client.keytab kafka-client@EXAMPLE.COM

# 查看服务日志
docker-compose logs kerberos-kdc
docker-compose logs kafka
```

## 故障排除

### 常见问题及解决方案

1. **端口连接问题**
   ```bash
   # 检查服务状态
   docker-compose ps

   # 重启服务
   docker-compose restart kafka
   ```

2. **Kerberos 认证失败**
   ```bash
   # 检查 KDC 日志
   docker-compose logs kerberos-kdc

   # 验证主体存在
   docker exec kerberos-kdc kadmin.local -q "listprincs"
   ```

3. **Zookeeper 连接问题**
   ```bash
   # 检查 Zookeeper 状态
   docker-compose logs zookeeper

   # 重启相关服务
   docker-compose restart zookeeper kafka
   ```

4. **应用启动失败**
   ```bash
   # 检查配置文件
   ./scripts/diagnose-kerberos-auth.sh

   # 查看详细错误日志
   tail -f /tmp/app_test.log
   ```

### 完整重置

如果遇到严重问题，可以执行完整重置：

```bash
# 停止所有服务
docker-compose down

# 清理数据卷
docker-compose down -v

# 重新启动
docker-compose up -d

# 等待服务启动完成
sleep 30

# 运行诊断
./scripts/diagnose-kerberos-auth.sh
```

## 文件结构

```
project/
├── docker-compose.yml              # 主配置文件
├── kerberos/                       # Kerberos 配置
│   ├── init-kerberos.sh           # KDC 初始化脚本
│   ├── kafka_server_jaas.conf     # Kafka 服务端 JAAS 配置
│   ├── krb5-docker.conf           # Kerberos 客户端配置
│   └── *.keytab                    # Keytab 文件
├── src/main/resources/             # 应用配置
│   ├── application-kerberos.yml    # Kerberos 应用配置
│   └── kafka_client_jaas.conf      # 客户端 JAAS 配置
└── scripts/                        # 工具脚本
    ├── test-kafka-kerberos-auth.sh     # 测试脚本
    ├── diagnose-kerberos-auth.sh       # 诊断脚本
    └── run-with-kerberos.sh            # 启动脚本
```

## 安全注意事项

1. **Keytab 文件权限**: 确保 keytab 文件有适当的权限 (600/644)
2. **网络安全**: 在生产环境中使用适当的网络隔离
3. **密码管理**: 定期更新 Kerberos 密码和 keytab 文件
4. **日志安全**: 避免在日志中暴露敏感信息

## 后续优化建议

1. **解决 Zookeeper 连接超时问题**
2. **添加 SSL/TLS 支持**
3. **实现多 Kafka 集群支持**
4. **添加监控和告警**
5. **优化性能配置**

## 联系和支持

如需技术支持，请参考：
- 项目文档: `README.md`
- 诊断工具: `./scripts/diagnose-kerberos-auth.sh`
- 测试工具: `./scripts/test-kafka-kerberos-auth.sh`

---

*文档生成时间: 2024-12-28*
*Kerberos 认证配置版本: 1.0*
