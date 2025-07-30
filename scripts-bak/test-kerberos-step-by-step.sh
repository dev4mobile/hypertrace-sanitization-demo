#!/bin/bash

# 分步测试 Kerberos 认证脚本
# 使用方法: ./scripts/test-kerberos-step-by-step.sh

echo "=== 分步测试 Kerberos 认证 ==="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 步骤1: 检查KDC状态
echo "步骤1: 检查 KDC 服务状态..."
if docker-compose ps kerberos-kdc | grep -q "Up"; then
    echo -e "${GREEN}✓${NC} KDC 服务正在运行"
else
    echo -e "${RED}✗${NC} KDC 服务未运行，正在启动..."
    docker-compose up -d kerberos-kdc
    sleep 10
fi

# 步骤2: 验证keytab文件
echo "步骤2: 验证 keytab 文件..."
if [ -f "./kerberos/kafka-client.keytab" ]; then
    echo -e "${GREEN}✓${NC} Kafka 客户端 keytab 文件存在"
else
    echo -e "${RED}✗${NC} Keytab 文件不存在，正在从容器复制..."
    docker cp kerberos-kdc:/var/kerberos/kafka-client.keytab ./kerberos/kafka-client.keytab
    chmod 600 ./kerberos/kafka-client.keytab
fi

# 步骤3: 测试KDC连接
echo "步骤3: 测试 KDC 连接..."
if nc -z 127.0.0.1 88 2>/dev/null; then
    echo -e "${GREEN}✓${NC} KDC 端口 88 可访问"
else
    echo -e "${RED}✗${NC} KDC 端口 88 不可访问"
    echo "请检查 Docker 端口映射"
fi

# 步骤4: 启动简单的Kafka (PLAINTEXT模式)
echo "步骤4: 启动 Kafka (PLAINTEXT 模式)..."
echo "首先测试 PLAINTEXT 连接..."

# 构建应用
echo "构建应用..."
./gradlew clean build -x test

if [ $? -ne 0 ]; then
    echo -e "${RED}构建失败${NC}"
    exit 1
fi

# 启动Zookeeper和Kafka (PLAINTEXT)
echo "启动 Zookeeper..."
docker-compose up -d zookeeper
sleep 10

# 修改Kafka配置为PLAINTEXT模式进行测试
echo "启动 Kafka (PLAINTEXT 模式)..."
export KAFKA_LISTENERS="PLAINTEXT://0.0.0.0:9092"
export KAFKA_ADVERTISED_LISTENERS="PLAINTEXT://localhost:9092"
export KAFKA_SECURITY_INTER_BROKER_PROTOCOL="PLAINTEXT"

# 启动应用 (PLAINTEXT 模式)
echo "启动应用 (PLAINTEXT 模式)..."
export SPRING_PROFILES_ACTIVE=default

JVM_OPTS="-javaagent:agents/hypertrace-agent.jar"
JVM_OPTS="$JVM_OPTS -Dhypertrace.service.name=user-service-test"
JVM_OPTS="$JVM_OPTS -Xmx512m -Xms256m"

echo -e "${YELLOW}测试 PLAINTEXT 模式...${NC}"
java $JVM_OPTS -jar build/libs/hypertrace-demo-0.0.1-SNAPSHOT.jar --spring.profiles.active=default &
APP_PID=$!

# 等待应用启动
echo "等待应用启动..."
sleep 30

# 测试API
echo "测试 API..."
if curl -s http://localhost:8080/actuator/health | grep -q "UP"; then
    echo -e "${GREEN}✓${NC} 应用启动成功 (PLAINTEXT 模式)"
    
    # 停止应用
    kill $APP_PID 2>/dev/null
    sleep 5
    
    echo -e "${YELLOW}现在测试 Kerberos 模式...${NC}"
    
    # 步骤5: 测试Kerberos模式
    echo "步骤5: 测试 Kerberos 认证..."
    
    # 设置Kerberos环境变量
    export SPRING_PROFILES_ACTIVE=kerberos
    
    # Kerberos JVM参数
    KERBEROS_OPTS="-Djava.security.auth.login.config=src/main/resources/kafka_client_jaas.conf"
    KERBEROS_OPTS="$KERBEROS_OPTS -Djava.security.krb5.conf=src/main/resources/krb5.conf"
    KERBEROS_OPTS="$KERBEROS_OPTS -Djavax.security.auth.useSubjectCredsOnly=false"
    
    ALL_JVM_OPTS="$JVM_OPTS $KERBEROS_OPTS"
    
    echo "启动应用 (Kerberos 模式)..."
    java $ALL_JVM_OPTS -jar build/libs/hypertrace-demo-0.0.1-SNAPSHOT.jar --spring.profiles.active=kerberos
    
else
    echo -e "${RED}✗${NC} 应用启动失败"
    kill $APP_PID 2>/dev/null
    exit 1
fi
