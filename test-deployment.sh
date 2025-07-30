#!/bin/bash

# Hypertrace Demo 部署测试脚本
# 用于验证部署是否成功

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "=== Hypertrace Demo 部署测试 ==="

# 测试计数器
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 测试函数
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    log_info "测试 $TOTAL_TESTS: $test_name"
    
    if eval "$test_command"; then
        log_success "✓ $test_name"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        log_error "✗ $test_name"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# 等待服务启动
wait_for_service() {
    local service_name="$1"
    local url="$2"
    local max_attempts=30
    local attempt=1
    
    log_info "等待 $service_name 启动..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "$url" > /dev/null 2>&1; then
            log_success "$service_name 已启动"
            return 0
        fi
        
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    log_error "$service_name 启动超时"
    return 1
}

# 1. 检查 Docker 服务
run_test "Docker 服务检查" "docker info > /dev/null 2>&1"

# 2. 检查 Docker Compose 文件
run_test "Docker Compose 配置检查" "docker-compose config > /dev/null 2>&1"

# 3. 检查容器状态
log_info "检查容器状态..."
if docker-compose ps | grep -q "Up"; then
    log_success "✓ 容器状态检查"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    log_error "✗ 容器状态检查 - 部分容器未运行"
    FAILED_TESTS=$((FAILED_TESTS + 1))
    docker-compose ps
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

# 4. 等待关键服务启动
wait_for_service "Spring Boot 应用" "http://localhost:8080"
wait_for_service "Jaeger UI" "http://localhost:16686"

# 5. 测试应用接口
log_info "测试应用接口..."

# 测试健康检查接口
run_test "健康检查接口" "curl -s -f http://localhost:8080/actuator/health > /dev/null 2>&1 || curl -s -f http://localhost:8080 > /dev/null 2>&1"

# 测试用户 API
log_info "测试用户 API..."

# 创建测试用户
USER_RESPONSE=$(curl -s -X POST http://localhost:8080/api/users \
    -H "Content-Type: application/json" \
    -d '{"name":"测试用户","email":"test@example.com","phone":"13800138000"}' 2>/dev/null)

if echo "$USER_RESPONSE" | grep -q "id"; then
    USER_ID=$(echo "$USER_RESPONSE" | grep -o '"id":[0-9]*' | cut -d':' -f2)
    log_success "✓ 用户创建测试 (ID: $USER_ID)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
    
    # 测试获取用户
    if curl -s -f "http://localhost:8080/api/users/$USER_ID" > /dev/null 2>&1; then
        log_success "✓ 用户查询测试"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        log_error "✗ 用户查询测试"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    
    # 测试 Kafka 通知
    if curl -s -f -X POST "http://localhost:8080/api/users/$USER_ID/notify" > /dev/null 2>&1; then
        log_success "✓ Kafka 通知测试"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        log_error "✗ Kafka 通知测试"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    
    TOTAL_TESTS=$((TOTAL_TESTS + 3))
else
    log_error "✗ 用户创建测试"
    log_error "✗ 用户查询测试"
    log_error "✗ Kafka 通知测试"
    FAILED_TESTS=$((FAILED_TESTS + 3))
    TOTAL_TESTS=$((TOTAL_TESTS + 3))
fi

# 6. 测试数据库连接
run_test "PostgreSQL 连接测试" "docker exec postgres pg_isready -U postgres > /dev/null 2>&1"

# 7. 测试 Kafka 服务
log_info "测试 Kafka 服务..."
if docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list > /dev/null 2>&1; then
    log_success "✓ Kafka 服务测试"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    log_error "✗ Kafka 服务测试"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

# 8. 测试 Jaeger 追踪数据
log_info "测试 Jaeger 追踪数据..."
sleep 5  # 等待追踪数据传输

JAEGER_API="http://localhost:16686/api/services"
if curl -s "$JAEGER_API" | grep -q "hypertrace-sanitization-demo-app"; then
    log_success "✓ Jaeger 追踪数据测试"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    log_warning "⚠ Jaeger 追踪数据测试 - 可能需要更多时间"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

# 9. 测试脱敏配置服务
run_test "脱敏配置后端测试" "curl -s -f http://localhost:3001/api/health > /dev/null 2>&1"
run_test "脱敏配置前端测试" "curl -s -f http://localhost:3000 > /dev/null 2>&1"

# 10. 资源使用检查
log_info "检查资源使用情况..."

# 检查内存使用
MEMORY_USAGE=$(docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}" | grep -E "(postgres|kafka|hypertrace)" | head -5)
if [ -n "$MEMORY_USAGE" ]; then
    log_info "容器内存使用情况:"
    echo "$MEMORY_USAGE"
fi

# 检查磁盘使用
DISK_USAGE=$(docker system df)
if [ -n "$DISK_USAGE" ]; then
    log_info "Docker 磁盘使用情况:"
    echo "$DISK_USAGE"
fi

# 测试结果汇总
echo ""
echo "================================================================"
log_info "测试结果汇总"
echo "================================================================"
echo "总测试数: $TOTAL_TESTS"
echo "通过测试: $PASSED_TESTS"
echo "失败测试: $FAILED_TESTS"
echo "成功率: $(( PASSED_TESTS * 100 / TOTAL_TESTS ))%"

if [ $FAILED_TESTS -eq 0 ]; then
    echo ""
    log_success "🎉 所有测试通过！部署成功！"
    echo ""
    echo "你现在可以访问以下服务:"
    echo "  - Spring Boot 应用: http://localhost:8080"
    echo "  - Jaeger UI: http://localhost:16686"
    echo "  - 脱敏配置管理: http://localhost:3000"
    echo ""
    echo "开始使用 Hypertrace Demo 吧！"
    exit 0
else
    echo ""
    log_error "❌ 部分测试失败，请检查以下内容:"
    echo "  1. 查看容器日志: docker-compose logs"
    echo "  2. 检查端口占用: lsof -i :8080"
    echo "  3. 重启服务: docker-compose restart"
    echo "  4. 完全重新部署: ./install.sh --clean"
    exit 1
fi