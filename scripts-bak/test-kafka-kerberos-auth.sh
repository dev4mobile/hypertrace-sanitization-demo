#!/bin/bash

# Kafka Kerberos 认证全面测试脚本
# 使用方法: ./scripts/test-kafka-kerberos-auth.sh

echo "=== Kafka Kerberos 认证全面测试 ==="
echo "测试时间: $(date)"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 测试结果统计
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 辅助函数
print_test_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED_TESTS++))
}

print_failure() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED_TESTS++))
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

print_info() {
    echo -e "${BLUE}i${NC} $1"
}

increment_test() {
    ((TOTAL_TESTS++))
}

# 1. 环境检查
print_test_header "环境检查"

# 检查必要的文件
print_info "检查必要文件..."
files_to_check=(
    "./kerberos/kafka.keytab"
    "./kerberos/kafka-client.keytab"
    "./kerberos/krb5-docker.conf"
    "./kerberos/kafka_server_jaas.conf"
    "src/main/resources/kafka_client_jaas.conf"
    "src/main/resources/application-kerberos.yml"
)

increment_test
all_files_exist=true
for file in "${files_to_check[@]}"; do
    if [ -f "$file" ]; then
        print_success "文件存在: $file"
    else
        print_failure "文件缺失: $file"
        all_files_exist=false
    fi
done

if [ "$all_files_exist" = true ]; then
    print_success "所有必要文件检查通过"
else
    print_failure "文件检查失败"
fi

echo ""

# 2. Docker 服务状态检查
print_test_header "Docker 服务状态检查"

# 检查 KDC 服务
increment_test
if docker-compose ps kerberos-kdc 2>/dev/null | grep -q "Up"; then
    print_success "KDC 服务正在运行"
else
    print_failure "KDC 服务未运行"
    print_info "请运行: docker-compose up -d kerberos-kdc"
fi

# 检查 Kafka 服务
increment_test
if docker-compose ps kafka 2>/dev/null | grep -q "Up"; then
    print_success "Kafka 服务正在运行"
else
    print_failure "Kafka 服务未运行"
    print_info "请运行: docker-compose up -d kafka"
fi

# 检查 Postgres 服务
increment_test
if docker-compose ps postgres 2>/dev/null | grep -q "Up"; then
    print_success "Postgres 服务正在运行"
else
    print_failure "Postgres 服务未运行"
    print_info "请运行: docker-compose up -d postgres"
fi

echo ""

# 3. 网络连接测试
print_test_header "网络连接测试"

# 检查 Kafka PLAINTEXT 端口
increment_test
if nc -z localhost 9092 2>/dev/null; then
    print_success "Kafka PLAINTEXT 端口 (9092) 可访问"
else
    print_failure "Kafka PLAINTEXT 端口 (9092) 不可访问"
fi

# 检查 Kafka SASL_PLAINTEXT 端口
increment_test
if nc -z localhost 9093 2>/dev/null; then
    print_success "Kafka SASL_PLAINTEXT 端口 (9093) 可访问"
else
    print_failure "Kafka SASL_PLAINTEXT 端口 (9093) 不可访问"
fi

# 检查 KDC 端口
increment_test
if nc -z localhost 88 2>/dev/null; then
    print_success "KDC 端口 (88) 可访问"
else
    print_failure "KDC 端口 (88) 不可访问"
fi

echo ""

# 4. Keytab 文件验证
print_test_header "Keytab 文件验证"

# 检查 Kafka 服务 keytab
increment_test
if command -v klist >/dev/null 2>&1; then
    print_info "验证 Kafka 服务 keytab..."
    if klist -kt ./kerberos/kafka.keytab >/dev/null 2>&1; then
        print_success "Kafka 服务 keytab 有效"
        print_info "Kafka 服务 keytab 内容:"
        klist -kt ./kerberos/kafka.keytab | head -10
    else
        print_failure "Kafka 服务 keytab 无效"
    fi
else
    print_warning "系统中没有 klist 命令，跳过 keytab 验证"
fi

# 检查 Kafka 客户端 keytab
increment_test
if command -v klist >/dev/null 2>&1; then
    print_info "验证 Kafka 客户端 keytab..."
    if klist -kt ./kerberos/kafka-client.keytab >/dev/null 2>&1; then
        print_success "Kafka 客户端 keytab 有效"
        print_info "Kafka 客户端 keytab 内容:"
        klist -kt ./kerberos/kafka-client.keytab | head -10
    else
        print_failure "Kafka 客户端 keytab 无效"
    fi
fi

echo ""

# 5. Kerberos 票据测试
print_test_header "Kerberos 票据测试"

# 设置 Kerberos 配置
export KRB5_CONFIG="./kerberos/krb5-docker.conf"

increment_test
if command -v kinit >/dev/null 2>&1; then
    print_info "尝试使用 keytab 获取票据..."
    if kinit -kt ./kerberos/kafka-client.keytab kafka-client@EXAMPLE.COM 2>/dev/null; then
        print_success "成功获取 Kerberos 票据"

        print_info "当前票据信息:"
        klist 2>/dev/null || print_warning "无法显示票据信息"
    else
        print_failure "无法获取 Kerberos 票据"
    fi
else
    print_warning "系统中没有 kinit 命令，跳过票据测试"
fi

echo ""

# 6. 应用构建测试
print_test_header "应用构建测试"

increment_test
print_info "构建应用..."
if ./gradlew build -x test --quiet 2>/dev/null; then
    print_success "应用构建成功"
else
    print_failure "应用构建失败"
    print_info "请检查构建日志: ./gradlew build -x test"
fi

echo ""

# 7. Kafka 消息测试（PLAINTEXT 模式）
print_test_header "Kafka 消息测试 (PLAINTEXT 模式)"

increment_test
print_info "测试 PLAINTEXT 模式的 Kafka 连接..."

# 创建测试主题
TOPIC_NAME="test-topic-plaintext-$(date +%s)"
if docker-compose exec kafka kafka-topics --create --topic $TOPIC_NAME --bootstrap-server localhost:9092 --partitions 1 --replication-factor 1 2>/dev/null; then
    print_success "成功创建测试主题: $TOPIC_NAME"

    # 测试消息发送
    TEST_MESSAGE="Hello from PLAINTEXT test at $(date)"
    if echo "$TEST_MESSAGE" | docker-compose exec -T kafka kafka-console-producer --topic $TOPIC_NAME --bootstrap-server localhost:9092 2>/dev/null; then
        print_success "成功发送测试消息"

        # 测试消息接收
        if timeout 10 docker-compose exec kafka kafka-console-consumer --topic $TOPIC_NAME --bootstrap-server localhost:9092 --from-beginning --max-messages 1 2>/dev/null | grep -q "Hello from PLAINTEXT"; then
            print_success "成功接收测试消息"
        else
            print_failure "未能接收测试消息"
        fi
    else
        print_failure "消息发送失败"
    fi

    # 清理测试主题
    docker-compose exec kafka kafka-topics --delete --topic $TOPIC_NAME --bootstrap-server localhost:9092 2>/dev/null
else
    print_failure "无法创建测试主题"
fi

echo ""

# 8. Kafka 消息测试（SASL_PLAINTEXT 模式）
print_test_header "Kafka 消息测试 (SASL_PLAINTEXT 模式)"

increment_test
print_info "测试 SASL_PLAINTEXT 模式的 Kafka 连接..."

# 创建临时 JAAS 配置文件
TEMP_JAAS_CONFIG="/tmp/kafka_test_jaas.conf"
cat > $TEMP_JAAS_CONFIG << EOF
KafkaClient {
    com.sun.security.auth.module.Krb5LoginModule required
    useKeyTab=true
    storeKey=true
    keyTab="$(pwd)/kerberos/kafka-client.keytab"
    principal="kafka-client@EXAMPLE.COM"
    serviceName="kafka";
};
EOF

# 创建测试主题
TOPIC_NAME_SASL="test-topic-sasl-$(date +%s)"
if docker-compose exec kafka kafka-topics --create --topic $TOPIC_NAME_SASL --bootstrap-server localhost:9093 --command-config <(echo "security.protocol=SASL_PLAINTEXT"; echo "sasl.mechanism=GSSAPI"; echo "sasl.kerberos.service.name=kafka") 2>/dev/null; then
    print_success "成功创建 SASL 测试主题: $TOPIC_NAME_SASL"

    print_info "SASL_PLAINTEXT 模式配置正确"
else
    print_failure "无法创建 SASL 测试主题"
    print_info "这可能是正常的，因为需要完整的 Kerberos 认证设置"
fi

# 清理临时文件
rm -f $TEMP_JAAS_CONFIG

echo ""

# 9. 应用集成测试
print_test_header "应用集成测试"

increment_test
print_info "启动应用进行集成测试..."

# 设置环境变量
export SPRING_PROFILES_ACTIVE=kerberos

# 启动应用（后台运行）
java -Djava.security.auth.login.config=src/main/resources/kafka_client_jaas.conf \
     -Djava.security.krb5.conf=./kerberos/krb5-docker.conf \
     -Djavax.security.auth.useSubjectCredsOnly=false \
     -Dsun.security.krb5.debug=false \
     -jar build/libs/hypertrace-demo-0.0.1-SNAPSHOT.jar \
     --spring.profiles.active=kerberos \
     --server.port=8081 > /tmp/app_test.log 2>&1 &

APP_PID=$!
print_info "应用 PID: $APP_PID"

# 等待应用启动
print_info "等待应用启动..."
sleep 30

# 检查应用是否还在运行
if kill -0 $APP_PID 2>/dev/null; then
    print_success "应用启动成功"

    # 等待应用完全启动
    for i in {1..10}; do
        if curl -s http://localhost:8081/actuator/health >/dev/null 2>&1; then
            print_success "应用健康检查通过"
            break
        fi
        print_info "等待应用启动... ($i/10)"
        sleep 3
    done

    # 测试用户通知 API
    if curl -s -X POST http://localhost:8081/api/users/1/notify >/dev/null 2>&1; then
        print_success "API 调用成功"
    else
        print_failure "API 调用失败"
    fi

    # 停止应用
    print_info "停止测试应用..."
    kill $APP_PID 2>/dev/null
    wait $APP_PID 2>/dev/null

else
    print_failure "应用启动失败"
    print_info "应用日志:"
    tail -20 /tmp/app_test.log 2>/dev/null || echo "无法读取应用日志"
fi

echo ""

# 10. 测试总结
print_test_header "测试总结"

echo "总测试数量: $TOTAL_TESTS"
echo -e "通过测试: ${GREEN}$PASSED_TESTS${NC}"
echo -e "失败测试: ${RED}$FAILED_TESTS${NC}"

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}✓ 所有测试通过！Kafka Kerberos 认证配置成功！${NC}"
    exit 0
else
    echo -e "${RED}✗ 有 $FAILED_TESTS 个测试失败，请检查配置${NC}"

    echo ""
    echo -e "${YELLOW}故障排除建议:${NC}"
    echo "1. 检查 KDC 服务日志: docker-compose logs kerberos-kdc"
    echo "2. 检查 Kafka 服务日志: docker-compose logs kafka"
    echo "3. 验证 Keytab 文件权限: ls -la kerberos/*.keytab"
    echo "4. 验证网络连接: nc -z localhost 88 && nc -z localhost 9093"
    echo "5. 查看应用日志: tail -50 /tmp/app_test.log"

    exit 1
fi
