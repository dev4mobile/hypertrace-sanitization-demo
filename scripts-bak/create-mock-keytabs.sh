#!/bin/bash

# 创建模拟 keytab 文件用于演示
# 使用方法: ./scripts/create-mock-keytabs.sh

echo "=== 创建模拟 Kerberos 环境 ==="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 创建 kerberos 目录
mkdir -p ./kerberos

echo "1. 创建模拟 keytab 文件..."

# 创建空的 keytab 文件（用于演示）
touch ./kerberos/kafka-client.keytab
touch ./kerberos/kafka.keytab

# 设置权限
chmod 600 ./kerberos/kafka-client.keytab
chmod 600 ./kerberos/kafka.keytab

echo -e "${GREEN}✓${NC} 模拟 keytab 文件已创建"

echo "2. 更新配置文件以使用 PLAINTEXT 连接..."

# 创建一个简化的配置文件，使用 PLAINTEXT 连接但保留 Kerberos 配置结构
cat > src/main/resources/application-kerberos-demo.yml << 'EOF'
# Kerberos 演示配置文件（使用 PLAINTEXT 连接）
# 使用方法: java -jar app.jar --spring.profiles.active=kerberos-demo

spring:
  kafka:
    bootstrap-servers: localhost:9092  # 使用 PLAINTEXT 端口
    consumer:
      group-id: user-group
      auto-offset-reset: earliest
      key-deserializer: org.apache.kafka.common.serialization.StringDeserializer
      value-deserializer: org.apache.kafka.common.serialization.StringDeserializer
    producer:
      key-serializer: org.apache.kafka.common.serialization.StringSerializer
      value-serializer: org.apache.kafka.common.serialization.StringSerializer

# Kerberos 配置（演示用，实际不会使用）
kerberos:
  principal: "kafka-client@EXAMPLE.COM"
  keytab: "./kerberos/kafka-client.keytab"
  service:
    name: "kafka"
  jaas:
    config: "classpath:kafka_client_jaas.conf"
  krb5:
    config: "classpath:krb5.conf"

# 日志配置
logging:
  level:
    com.example.hypertracedemo: DEBUG
    org.springframework.kafka: DEBUG
EOF

echo -e "${GREEN}✓${NC} 演示配置文件已创建: src/main/resources/application-kerberos-demo.yml"

echo "3. 创建演示启动脚本..."

cat > scripts/run-kerberos-demo.sh << 'EOF'
#!/bin/bash

# Kafka Kerberos 演示启动脚本（使用 PLAINTEXT 连接）
# 使用方法: ./scripts/run-kerberos-demo.sh

echo "=== 启动 Kafka 应用 (Kerberos 演示模式) ==="

# 检查 Kafka 是否运行
if ! nc -z localhost 9092 2>/dev/null; then
    echo "错误: Kafka 服务未运行，请先启动 Kafka"
    echo "运行: docker-compose up -d kafka"
    exit 1
fi

echo "✓ Kafka 服务正在运行"

# 构建应用
echo "构建应用..."
./gradlew build -x test --quiet

if [ $? -ne 0 ]; then
    echo "构建失败，退出"
    exit 1
fi

echo "✓ 应用构建完成"

# JVM 参数（演示用）
JVM_OPTS="-Xmx512m -Xms256m"

# 应用配置
APP_OPTS="--spring.profiles.active=kerberos-demo"

echo "配置信息:"
echo "  模式: Kerberos 演示 (PLAINTEXT 连接)"
echo "  Kafka: localhost:9092"
echo "  Profile: kerberos-demo"
echo ""

echo "启动应用..."
java ${JVM_OPTS} -jar build/libs/hypertrace-demo-0.0.1-SNAPSHOT.jar ${APP_OPTS}
EOF

chmod +x scripts/run-kerberos-demo.sh

echo -e "${GREEN}✓${NC} 演示启动脚本已创建: scripts/run-kerberos-demo.sh"

echo "4. 启动基础服务..."

# 启动基础服务（不包括 KDC）
docker-compose up -d zookeeper kafka jaeger postgres

echo "等待服务启动..."
sleep 15

# 检查服务状态
if docker-compose ps kafka | grep -q "Up"; then
    echo -e "${GREEN}✓${NC} Kafka 服务运行正常"
else
    echo -e "${RED}✗${NC} Kafka 服务启动失败"
    docker-compose logs kafka
    exit 1
fi

echo ""
echo -e "${GREEN}=== 模拟 Kerberos 环境创建完成 ===${NC}"
echo ""
echo -e "${YELLOW}演示说明:${NC}"
echo "由于网络限制，我们创建了一个模拟的 Kerberos 环境用于演示。"
echo "应用将使用 PLAINTEXT 连接到 Kafka，但保留了完整的 Kerberos 配置结构。"
echo ""
echo -e "${YELLOW}使用方法:${NC}"
echo "1. 启动演示应用: ./scripts/run-kerberos-demo.sh"
echo "2. 测试 API: curl -X POST http://localhost:8080/api/users/1/notify"
echo "3. 查看追踪: http://localhost:16686"
echo ""
echo -e "${YELLOW}文件说明:${NC}"
echo "- ./kerberos/kafka-client.keytab: 模拟客户端 keytab"
echo "- ./kerberos/kafka.keytab: 模拟服务器 keytab"
echo "- src/main/resources/application-kerberos-demo.yml: 演示配置"
echo "- scripts/run-kerberos-demo.sh: 演示启动脚本"
echo ""
echo -e "${YELLOW}真实环境:${NC}"
echo "在真实的 Kerberos 环境中，您需要:"
echo "1. 配置 KDC 服务器"
echo "2. 生成真实的 keytab 文件"
echo "3. 使用 SASL_PLAINTEXT 或 SASL_SSL 协议"
echo "4. 配置正确的 realm 和 principal"
EOF

chmod +x scripts/create-mock-keytabs.sh

echo -e "${GREEN}✓${NC} 模拟环境创建脚本已保存: scripts/create-mock-keytabs.sh"
