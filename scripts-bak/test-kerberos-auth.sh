#!/bin/bash

# Kerberos 认证测试脚本
# 使用方法: ./scripts/test-kerberos-auth.sh

echo "=== Kafka Kerberos 认证测试 ==="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查必要的文件
echo "1. 检查必要文件..."

files_to_check=(
    "./kerberos/kafka-client.keytab"
    "./kerberos/krb5.conf"
    "src/main/resources/kafka_client_jaas.conf"
    "src/main/resources/application-kerberos.yml"
)

all_files_exist=true
for file in "${files_to_check[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $file"
    else
        echo -e "${RED}✗${NC} $file (不存在)"
        all_files_exist=false
    fi
done

if [ "$all_files_exist" = false ]; then
    echo -e "${RED}错误: 缺少必要文件，请先运行 ./scripts/setup-kerberos.sh${NC}"
    exit 1
fi

echo ""
echo "2. 检查 Kerberos 服务..."

# 检查 KDC 服务
if docker-compose ps kerberos-kdc | grep -q "Up"; then
    echo -e "${GREEN}✓${NC} KDC 服务正在运行"
else
    echo -e "${RED}✗${NC} KDC 服务未运行"
    echo "请运行: ./scripts/setup-kerberos.sh"
    exit 1
fi

# 检查 Kafka 服务
if docker-compose ps kafka | grep -q "Up"; then
    echo -e "${GREEN}✓${NC} Kafka 服务正在运行"
else
    echo -e "${RED}✗${NC} Kafka 服务未运行"
    echo "请运行: ./scripts/setup-kerberos.sh"
    exit 1
fi

echo ""
echo "3. 测试 Kerberos 票据..."

# 设置 Kerberos 配置
export KRB5_CONFIG="./kerberos/krb5.conf"

# 测试 keytab 文件
if command -v klist >/dev/null 2>&1; then
    echo "Keytab 文件内容:"
    klist -kt ./kerberos/kafka-client.keytab
    
    echo ""
    echo "尝试使用 keytab 获取票据..."
    if kinit -kt ./kerberos/kafka-client.keytab kafka-client@EXAMPLE.COM; then
        echo -e "${GREEN}✓${NC} 成功获取 Kerberos 票据"
        
        echo "当前票据:"
        klist
    else
        echo -e "${RED}✗${NC} 无法获取 Kerberos 票据"
    fi
else
    echo -e "${YELLOW}!${NC} 系统中没有 klist 命令，跳过票据测试"
fi

echo ""
echo "4. 测试 Kafka 连接..."

# 检查 Kafka 端口是否可访问
if nc -z localhost 9093 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Kafka SASL_PLAINTEXT 端口 (9093) 可访问"
else
    echo -e "${RED}✗${NC} Kafka SASL_PLAINTEXT 端口 (9093) 不可访问"
fi

if nc -z localhost 9092 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Kafka PLAINTEXT 端口 (9092) 可访问"
else
    echo -e "${RED}✗${NC} Kafka PLAINTEXT 端口 (9092) 不可访问"
fi

echo ""
echo "5. 构建并测试应用..."

# 构建应用
echo "构建应用..."
if ./gradlew build -x test --quiet; then
    echo -e "${GREEN}✓${NC} 应用构建成功"
else
    echo -e "${RED}✗${NC} 应用构建失败"
    exit 1
fi

# 启动应用进行测试
echo ""
echo "启动应用进行 Kerberos 认证测试..."
echo "这将启动应用并尝试连接到 Kafka..."

# 设置环境变量
export SPRING_PROFILES_ACTIVE=kerberos

# 启动应用（后台运行）
java -Djava.security.auth.login.config=src/main/resources/kafka_client_jaas.conf \
     -Djava.security.krb5.conf=./kerberos/krb5.conf \
     -Djavax.security.auth.useSubjectCredsOnly=false \
     -Dsun.security.krb5.debug=false \
     -jar build/libs/hypertrace-demo-0.0.1-SNAPSHOT.jar \
     --spring.profiles.active=kerberos \
     --kerberos.principal=kafka-client@EXAMPLE.COM \
     --kerberos.keytab=./kerberos/kafka-client.keytab \
     --kerberos.service.name=kafka \
     --server.port=8080 &

APP_PID=$!

echo "应用 PID: $APP_PID"
echo "等待应用启动..."

# 等待应用启动
sleep 30

# 检查应用是否还在运行
if kill -0 $APP_PID 2>/dev/null; then
    echo -e "${GREEN}✓${NC} 应用启动成功"
    
    # 测试 API 调用
    echo ""
    echo "6. 测试 API 调用..."
    
    # 等待应用完全启动
    for i in {1..10}; do
        if curl -s http://localhost:8080/actuator/health >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} 应用健康检查通过"
            break
        fi
        echo "等待应用启动... ($i/10)"
        sleep 3
    done
    
    # 测试用户通知 API
    echo "测试用户通知 API..."
    if curl -X POST http://localhost:8080/api/users/1/notify -v; then
        echo -e "${GREEN}✓${NC} API 调用成功"
    else
        echo -e "${RED}✗${NC} API 调用失败"
    fi
    
    echo ""
    echo "7. 检查应用日志..."
    echo "请查看应用日志中的 Kerberos 相关信息"
    
    # 停止应用
    echo ""
    echo "停止测试应用..."
    kill $APP_PID
    wait $APP_PID 2>/dev/null
    
else
    echo -e "${RED}✗${NC} 应用启动失败"
    echo "请检查应用日志"
fi

echo ""
echo "=== 测试完成 ==="
echo ""
echo -e "${YELLOW}如果测试成功，您可以:${NC}"
echo "1. 使用 ./scripts/run-with-kerberos.sh 正常启动应用"
echo "2. 访问 http://localhost:16686 查看 Jaeger 追踪"
echo "3. 测试 Kafka 消息: curl -X POST http://localhost:8080/api/users/1/notify"
echo ""
echo -e "${YELLOW}如果测试失败，请检查:${NC}"
echo "1. KDC 服务日志: docker-compose logs kerberos-kdc"
echo "2. Kafka 服务日志: docker-compose logs kafka"
echo "3. 应用启动日志中的 Kerberos 错误信息"
