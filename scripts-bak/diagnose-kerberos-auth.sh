#!/bin/bash

# Kerberos 认证诊断和故障排除脚本
# 使用方法: ./scripts/diagnose-kerberos-auth.sh

echo "=== Kafka Kerberos 认证诊断工具 ==="
echo "诊断时间: $(date)"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 辅助函数
print_section() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_failure() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

print_info() {
    echo -e "${BLUE}i${NC} $1"
}

# 1. 系统环境检查
print_section "系统环境检查"

print_info "操作系统信息:"
uname -a

print_info "Java 版本:"
java -version 2>&1

print_info "Docker 状态:"
docker --version 2>/dev/null || print_warning "Docker 未安装或不可用"

print_info "Docker Compose 状态:"
docker-compose --version 2>/dev/null || print_warning "Docker Compose 未安装或不可用"

print_info "网络工具:"
which nc >/dev/null && print_success "nc 工具可用" || print_warning "nc 工具不可用"
which kinit >/dev/null && print_success "kinit 工具可用" || print_warning "kinit 工具不可用"
which klist >/dev/null && print_success "klist 工具可用" || print_warning "klist 工具不可用"

echo ""

# 2. 配置文件检查
print_section "配置文件检查"

CONFIG_FILES=(
    "docker-compose.yml"
    "kerberos/kdc.conf"
    "kerberos/krb5-docker.conf"
    "kerberos/kafka_server_jaas.conf"
    "src/main/resources/application-kerberos.yml"
    "src/main/resources/kafka_client_jaas.conf"
)

for file in "${CONFIG_FILES[@]}"; do
    if [ -f "$file" ]; then
        print_success "配置文件存在: $file"

        # 检查配置文件内容
        case "$file" in
            "src/main/resources/application-kerberos.yml")
                if grep -q "localhost:9093" "$file"; then
                    print_success "  应用配置指向 SASL_PLAINTEXT 端口"
                else
                    print_failure "  应用配置未指向 SASL_PLAINTEXT 端口"
                fi
                ;;
            "docker-compose.yml")
                if grep -q "KAFKA_SASL_ENABLED_MECHANISMS: GSSAPI" "$file"; then
                    print_success "  Kafka SASL 配置已启用"
                else
                    print_failure "  Kafka SASL 配置未启用"
                fi
                ;;
        esac
    else
        print_failure "配置文件缺失: $file"
    fi
done

echo ""

# 3. Keytab 文件检查
print_section "Keytab 文件检查"

KEYTAB_FILES=(
    "kerberos/kafka.keytab"
    "kerberos/kafka-client.keytab"
)

for keytab in "${KEYTAB_FILES[@]}"; do
    if [ -f "$keytab" ]; then
        print_success "Keytab 文件存在: $keytab"

        # 检查文件权限
        perms=$(stat -c "%a" "$keytab" 2>/dev/null || stat -f "%A" "$keytab" 2>/dev/null)
        print_info "  文件权限: $perms"

        # 检查文件内容
        if command -v klist >/dev/null 2>&1; then
            if klist -kt "$keytab" >/dev/null 2>&1; then
                print_success "  Keytab 文件有效"
                print_info "  Keytab 内容:"
                klist -kt "$keytab" | head -5
            else
                print_failure "  Keytab 文件无效"
            fi
        else
            print_warning "  无法验证 Keytab 文件（缺少 klist）"
        fi
    else
        print_failure "Keytab 文件缺失: $keytab"
    fi
done

echo ""

# 4. Docker 容器状态检查
print_section "Docker 容器状态检查"

CONTAINERS=(
    "kerberos-kdc"
    "kafka"
    "zookeeper"
    "postgres"
)

for container in "${CONTAINERS[@]}"; do
    if docker-compose ps "$container" 2>/dev/null | grep -q "Up"; then
        print_success "容器正在运行: $container"

        # 检查容器健康状态
        if docker exec "$container" ps aux >/dev/null 2>&1; then
            print_success "  容器响应正常"
        else
            print_warning "  容器可能存在问题"
        fi
    else
        print_failure "容器未运行: $container"
        print_info "  使用以下命令启动: docker-compose up -d $container"
    fi
done

echo ""

# 5. 网络连接检查
print_section "网络连接检查"

PORTS=(
    "88:KDC"
    "9092:Kafka-PLAINTEXT"
    "9093:Kafka-SASL_PLAINTEXT"
    "2181:Zookeeper"
    "5432:PostgreSQL"
)

for port_info in "${PORTS[@]}"; do
    port=$(echo "$port_info" | cut -d: -f1)
    service=$(echo "$port_info" | cut -d: -f2)

    if nc -z localhost "$port" 2>/dev/null; then
        print_success "端口可访问: $port ($service)"
    else
        print_failure "端口不可访问: $port ($service)"
    fi
done

echo ""

# 6. Kerberos 服务检查
print_section "Kerberos 服务检查"

# 检查 KDC 服务
if docker exec kerberos-kdc ps aux | grep -q krb5kdc; then
    print_success "KDC 服务进程正在运行"
else
    print_failure "KDC 服务进程未运行"
fi

# 检查 kadmin 服务
if docker exec kerberos-kdc ps aux | grep -q kadmind; then
    print_success "Kadmin 服务进程正在运行"
else
    print_failure "Kadmin 服务进程未运行"
fi

# 检查 Kerberos 主体
print_info "检查 Kerberos 主体..."
if docker exec kerberos-kdc kadmin.local -q "listprincs" 2>/dev/null | grep -q "kafka/kafka.example.com"; then
    print_success "Kafka 服务主体存在"
else
    print_failure "Kafka 服务主体不存在"
fi

if docker exec kerberos-kdc kadmin.local -q "listprincs" 2>/dev/null | grep -q "kafka-client"; then
    print_success "Kafka 客户端主体存在"
else
    print_failure "Kafka 客户端主体不存在"
fi

echo ""

# 7. Kafka 配置检查
print_section "Kafka 配置检查"

# 检查 Kafka 监听器
if docker exec kafka netstat -tlnp 2>/dev/null | grep -q ":9092"; then
    print_success "Kafka PLAINTEXT 监听器正在运行"
else
    print_failure "Kafka PLAINTEXT 监听器未运行"
fi

if docker exec kafka netstat -tlnp 2>/dev/null | grep -q ":9093"; then
    print_success "Kafka SASL_PLAINTEXT 监听器正在运行"
else
    print_failure "Kafka SASL_PLAINTEXT 监听器未运行"
fi

# 检查 Kafka 配置文件
if docker exec kafka test -f /etc/kafka/kafka_server_jaas.conf; then
    print_success "Kafka 服务 JAAS 配置文件存在"
else
    print_failure "Kafka 服务 JAAS 配置文件不存在"
fi

if docker exec kafka test -f /etc/kafka/krb5.conf; then
    print_success "Kafka 服务 Kerberos 配置文件存在"
else
    print_failure "Kafka 服务 Kerberos 配置文件不存在"
fi

echo ""

# 8. 应用构建检查
print_section "应用构建检查"

if [ -f "build/libs/hypertrace-demo-0.0.1-SNAPSHOT.jar" ]; then
    print_success "应用 JAR 文件存在"

    # 检查 JAR 文件时间
    jar_time=$(stat -c "%Y" "build/libs/hypertrace-demo-0.0.1-SNAPSHOT.jar" 2>/dev/null || stat -f "%m" "build/libs/hypertrace-demo-0.0.1-SNAPSHOT.jar" 2>/dev/null)
    current_time=$(date +%s)
    time_diff=$((current_time - jar_time))

    if [ $time_diff -lt 3600 ]; then
        print_success "  JAR 文件是最新的（不到1小时前构建）"
    else
        print_warning "  JAR 文件可能过时（超过1小时前构建）"
        print_info "  建议重新构建: ./gradlew build"
    fi
else
    print_failure "应用 JAR 文件不存在"
    print_info "  请运行构建命令: ./gradlew build"
fi

echo ""

# 9. 日志分析
print_section "日志分析"

print_info "检查 Docker 容器日志..."

# 检查 KDC 日志
if docker-compose logs kerberos-kdc 2>/dev/null | grep -q "error\|Error\|ERROR"; then
    print_warning "KDC 日志中发现错误"
    print_info "  查看详细日志: docker-compose logs kerberos-kdc"
else
    print_success "KDC 日志没有明显错误"
fi

# 检查 Kafka 日志
if docker-compose logs kafka 2>/dev/null | grep -q "error\|Error\|ERROR"; then
    print_warning "Kafka 日志中发现错误"
    print_info "  查看详细日志: docker-compose logs kafka"
else
    print_success "Kafka 日志没有明显错误"
fi

echo ""

# 10. 常见问题解决方案
print_section "常见问题解决方案"

echo "如果遇到问题，请尝试以下解决方案:"
echo ""
echo "1. 时间同步问题:"
echo "   - Kerberos 对时间敏感，确保容器时间同步"
echo "   - 重启 Docker 服务可能有帮助"
echo ""
echo "2. Keytab 文件问题:"
echo "   - 重新生成 Keytab 文件: docker-compose restart kerberos-kdc"
echo "   - 检查文件权限: chmod 644 kerberos/*.keytab"
echo ""
echo "3. 网络连接问题:"
echo "   - 检查防火墙设置"
echo "   - 确保端口未被占用: netstat -tlnp | grep -E '88|9092|9093'"
echo ""
echo "4. 配置文件问题:"
echo "   - 验证配置文件语法"
echo "   - 检查文件路径是否正确"
echo ""
echo "5. 应用启动问题:"
echo "   - 检查 JVM 参数设置"
echo "   - 确保 classpath 包含所有必要的库"
echo ""
echo "6. 完整重置:"
echo "   - 停止所有服务: docker-compose down"
echo "   - 清理数据: docker-compose down -v"
echo "   - 重新启动: docker-compose up -d"
echo ""

# 11. 快速测试建议
print_section "快速测试建议"

echo "执行以下测试来验证配置:"
echo ""
echo "1. 运行完整测试:"
echo "   ./scripts/test-kafka-kerberos-auth.sh"
echo ""
echo "2. 快速连接测试:"
echo "   nc -z localhost 88 && echo 'KDC 可访问'"
echo "   nc -z localhost 9093 && echo 'Kafka SASL 可访问'"
echo ""
echo "3. Keytab 验证:"
echo "   klist -kt kerberos/kafka-client.keytab"
echo ""
echo "4. 启动应用:"
echo "   ./scripts/run-with-kerberos.sh"
echo ""
echo "5. 查看日志:"
echo "   docker-compose logs -f kerberos-kdc"
echo "   docker-compose logs -f kafka"
echo ""

echo "=== 诊断完成 ==="
