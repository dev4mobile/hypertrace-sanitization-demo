# Kafka Kerberos 认证配置指南

本文档介绍如何为 Kafka 应用配置 Kerberos 认证。

## 概述

本项目已经添加了完整的 Kafka Kerberos 认证支持，包括：

- **完整的 Kerberos 环境**: 包含 KDC 服务器、Kafka 服务器和客户端配置
- **Docker 化部署**: 使用 Docker Compose 一键启动 Kerberos 环境
- **自动配置**: 自动生成 keytab 文件和配置 Kerberos 安全设置
- **双端口支持**: 同时支持 PLAINTEXT (9092) 和 SASL_PLAINTEXT (9093) 连接
- **生产者和消费者认证**: 完整的 Kafka 客户端 Kerberos 认证
- **配置验证和错误处理**: 启动时验证配置完整性

## 文件结构

```
# Docker 环境配置
docker-compose.yml                   # 包含 KDC、Kafka 等服务
kerberos/
├── krb5.conf                        # Kerberos 客户端配置
├── kdc.conf                         # KDC 服务器配置
├── kadm5.acl                        # Kerberos 管理员权限
├── kafka_server_jaas.conf           # Kafka 服务器 JAAS 配置
├── init-kerberos.sh                 # KDC 初始化脚本
├── kafka-client.keytab              # 客户端 keytab (自动生成)
└── kafka.keytab                     # 服务器 keytab (自动生成)

# 应用配置
src/main/resources/
├── application-kerberos.yml         # Kerberos 专用配置文件
├── kafka_client_jaas.conf           # 客户端 JAAS 配置
└── krb5.conf                        # 客户端 Kerberos 配置

# Java 代码
src/main/java/com/example/hypertracedemo/
├── config/KafkaConfig.java          # 更新的 Kafka 配置类
└── service/KerberosConfigService.java # Kerberos 配置服务

# 脚本工具
scripts/
├── setup-kerberos.sh                # Kerberos 环境设置脚本
├── run-with-kerberos.sh             # Kerberos 启动脚本
├── test-kerberos-config.sh          # 配置测试脚本
└── test-kerberos-auth.sh            # 认证测试脚本
```

## 快速开始

### 方法 1: 一键设置（推荐）

```bash
# 1. 设置 Kerberos 环境（包含 KDC、Kafka 等服务）
./scripts/setup-kerberos.sh

# 2. 测试配置
./scripts/test-kerberos-config.sh

# 3. 测试认证
./scripts/test-kerberos-auth.sh

# 4. 启动应用
./scripts/run-with-kerberos.sh
```

### 方法 2: 手动设置

#### 1. 启动 Kerberos 环境

```bash
# 启动 KDC 服务
docker-compose up -d kerberos-kdc

# 等待服务启动
sleep 15

# 启动 Kafka 服务
docker-compose up -d zookeeper kafka
```

#### 2. 提取 Keytab 文件

```bash
# 从 KDC 容器中复制 keytab 文件
docker cp kerberos-kdc:/tmp/kafka-client.keytab ./kerberos/kafka-client.keytab
docker cp kerberos-kdc:/tmp/kafka.keytab ./kerberos/kafka.keytab

# 设置正确的权限
chmod 600 ./kerberos/kafka-client.keytab
chmod 600 ./kerberos/kafka.keytab
```

### 3. 配置文件设置

#### 3.1 更新 krb5.conf

编辑 `src/main/resources/krb5.conf`：

```ini
[libdefaults]
    default_realm = YOUR-REALM.COM
    dns_lookup_realm = false
    dns_lookup_kdc = false
    ticket_lifetime = 24h
    renew_lifetime = 7d
    forwardable = true

[realms]
    YOUR-REALM.COM = {
        kdc = your-kdc-server.com:88
        admin_server = your-kdc-server.com:749
        default_domain = your-domain.com
    }

[domain_realm]
    .your-domain.com = YOUR-REALM.COM
    your-domain.com = YOUR-REALM.COM
```

#### 3.2 更新 JAAS 配置

编辑 `src/main/resources/kafka_client_jaas.conf`：

```
KafkaClient {
    com.sun.security.auth.module.Krb5LoginModule required
    useKeyTab=true
    storeKey=true
    keyTab="/path/to/your/kafka-client.keytab"
    principal="kafka-client@YOUR-REALM.COM"
    serviceName="kafka";
};
```

#### 3.3 更新应用配置

编辑 `src/main/resources/application-kerberos.yml`：

```yaml
kerberos:
  principal: "kafka-client@YOUR-REALM.COM"
  keytab: "/path/to/your/kafka-client.keytab"
  service:
    name: "kafka"
  jaas:
    config: "classpath:kafka_client_jaas.conf"
  krb5:
    config: "classpath:krb5.conf"
```

### 4. Kafka Broker 配置

确保您的 Kafka broker 也配置了 Kerberos 认证：

```properties
# server.properties
listeners=SASL_PLAINTEXT://localhost:9092
security.inter.broker.protocol=SASL_PLAINTEXT
sasl.mechanism.inter.broker.protocol=GSSAPI
sasl.enabled.mechanisms=GSSAPI
sasl.kerberos.service.name=kafka
```

## 使用方法

### 方法 1: 使用启动脚本

```bash
# 修改脚本中的配置路径
vim scripts/run-with-kerberos.sh

# 运行应用
./scripts/run-with-kerberos.sh
```

### 方法 2: 使用 Spring Profile

```bash
# 构建应用
./gradlew build

# 使用 kerberos profile 启动
java -jar build/libs/hypertrace-demo-0.0.1-SNAPSHOT.jar \
  --spring.profiles.active=kerberos \
  --kerberos.principal=kafka-client@YOUR-REALM.COM \
  --kerberos.keytab=/path/to/kafka-client.keytab
```

### 方法 3: 使用 JVM 参数

```bash
java -Djava.security.auth.login.config=src/main/resources/kafka_client_jaas.conf \
     -Djava.security.krb5.conf=src/main/resources/krb5.conf \
     -Djavax.security.auth.useSubjectCredsOnly=false \
     -jar build/libs/hypertrace-demo-0.0.1-SNAPSHOT.jar \
     --spring.profiles.active=kerberos
```

## 调试

### 启用 Kerberos 调试

```bash
export DEBUG=true
./scripts/run-with-kerberos.sh
```

或者添加 JVM 参数：

```bash
-Dsun.security.krb5.debug=true
-Dsun.security.jgss.debug=true
```

### 常见问题

1. **认证失败**
   - 检查 keytab 文件权限
   - 验证 principal 名称
   - 确认 KDC 服务器可达

2. **配置文件找不到**
   - 检查文件路径
   - 确认 classpath 配置

3. **时钟同步问题**
   - 确保客户端和 KDC 时钟同步
   - 检查时区设置

## 验证

### 检查认证状态

应用启动后，查看日志中的 Kerberos 配置信息：

```
Kerberos Configuration:
  Principal: kafka-client@YOUR-REALM.COM
  Service Name: kafka
  Keytab: /path/to/kafka-client.keytab
  KRB5 Config: /path/to/krb5.conf
  JAAS Config: /path/to/kafka_client_jaas.conf
```

### 测试 Kafka 连接

```bash
# 发送测试消息
curl -X POST http://localhost:8080/api/users/1/notify

# 检查应用日志中的 Kafka 消息
```

## 安全注意事项

1. **Keytab 文件安全**
   - 设置适当的文件权限 (600)
   - 定期轮换密钥
   - 避免在版本控制中存储 keytab

2. **网络安全**
   - 使用 SASL_SSL 而不是 SASL_PLAINTEXT（生产环境）
   - 配置适当的防火墙规则

3. **监控和审计**
   - 监控认证失败事件
   - 定期检查 Kerberos 票据状态

## 生产环境配置

对于生产环境，建议：

1. 使用 SASL_SSL 协议
2. 配置证书验证
3. 启用审计日志
4. 设置适当的票据生命周期
5. 配置高可用 KDC
