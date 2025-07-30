#!/bin/bash

# Hypertrace Demo 一键安装脚本
# 支持 Docker Compose 部署

set -e

echo "=== Hypertrace Demo 一键安装脚本 ==="

# 配置变量
PROJECT_NAME="hypertrace-demo"
REQUIRED_PORTS=(8080 16686 9092 2181 5432 3000 3001 55432)
COMPOSE_CMD=""

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

# 检查系统要求
check_requirements() {
    log_info "检查系统要求..."
    
    # 检查操作系统
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        log_info "检测到 Linux 系统"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        log_info "检测到 macOS 系统"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        log_info "检测到 Windows 系统"
    else
        log_warning "未知操作系统: $OSTYPE"
    fi
    
    # 检查 Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装"
        echo "请先安装 Docker:"
        echo "  Linux: https://docs.docker.com/engine/install/"
        echo "  macOS: https://docs.docker.com/desktop/mac/"
        echo "  Windows: https://docs.docker.com/desktop/windows/"
        exit 1
    fi
    
    # 检查 Docker 版本
    DOCKER_VERSION=$(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    log_info "Docker 版本: $DOCKER_VERSION"
    
    # 检查 Docker Compose
    if command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
        COMPOSE_VERSION=$(docker-compose --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        log_info "Docker Compose 版本: $COMPOSE_VERSION (standalone)"
    elif docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
        COMPOSE_VERSION=$(docker compose version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        log_info "Docker Compose 版本: $COMPOSE_VERSION (plugin)"
    else
        log_error "Docker Compose 未安装"
        echo "请先安装 Docker Compose: https://docs.docker.com/compose/install/"
        exit 1
    fi
    
    # 检查 Docker 服务状态
    if ! docker info &> /dev/null; then
        log_error "Docker 服务未运行"
        echo "请启动 Docker 服务:"
        echo "  Linux: sudo systemctl start docker"
        echo "  macOS/Windows: 启动 Docker Desktop"
        exit 1
    fi
    
    # 检查内存
    if command -v free &> /dev/null; then
        TOTAL_MEM=$(free -m | awk 'NR==2{printf "%.0f", $2/1024}')
        if [ "$TOTAL_MEM" -lt 4 ]; then
            log_warning "系统内存较少 (${TOTAL_MEM}GB)，建议至少 4GB"
        else
            log_info "系统内存: ${TOTAL_MEM}GB"
        fi
    fi
    
    log_success "系统要求检查通过"
}

# 检查端口占用
check_ports() {
    log_info "检查端口占用..."
    
    occupied_ports=()
    
    for port in "${REQUIRED_PORTS[@]}"; do
        if command -v lsof &> /dev/null; then
            if lsof -i :$port &> /dev/null; then
                occupied_ports+=($port)
            fi
        elif command -v netstat &> /dev/null; then
            if netstat -tuln | grep ":$port " &> /dev/null; then
                occupied_ports+=($port)
            fi
        elif command -v ss &> /dev/null; then
            if ss -tuln | grep ":$port " &> /dev/null; then
                occupied_ports+=($port)
            fi
        fi
    done
    
    if [ ${#occupied_ports[@]} -gt 0 ]; then
        log_warning "以下端口被占用: ${occupied_ports[*]}"
        echo "端口说明:"
        echo "  8080  - Spring Boot 应用"
        echo "  16686 - Jaeger UI"
        echo "  9092  - Kafka"
        echo "  2181  - Zookeeper"
        echo "  5432  - PostgreSQL"
        echo "  3000  - 脱敏配置前端"
        echo "  3001  - 脱敏配置后端"
        echo "  55432 - 脱敏配置数据库"
        echo ""
        read -p "是否继续安装? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "安装已取消"
            exit 1
        fi
    else
        log_success "端口检查通过"
    fi
}

# 检查必要文件
check_files() {
    log_info "检查必要文件..."
    
    required_files=(
        "docker-compose.yml"
        "Dockerfile"
    )
    
    missing_files=()
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            missing_files+=($file)
        fi
    done
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        log_error "缺少必要文件: ${missing_files[*]}"
        echo "请确保在项目根目录运行此脚本"
        exit 1
    fi
    
    log_success "文件检查通过"
}

# 下载 Hypertrace Agent
download_agent() {
    log_info "检查 Hypertrace Agent..."
    
    mkdir -p agents
    
    AGENT_FILE="agents/hypertrace-agent-1.3.25.jar"
    if [ ! -f "$AGENT_FILE" ]; then
        log_info "下载 Hypertrace Agent..."
        
        AGENT_URL="https://github.com/hypertrace/javaagent/releases/download/1.3.25/hypertrace-agent-1.3.25-all.jar"
        
        if command -v curl &> /dev/null; then
            curl -L -o "$AGENT_FILE" "$AGENT_URL"
        elif command -v wget &> /dev/null; then
            wget -O "$AGENT_FILE" "$AGENT_URL"
        else
            log_error "需要 curl 或 wget 来下载 Hypertrace Agent"
            exit 1
        fi
        
        if [ ! -f "$AGENT_FILE" ]; then
            log_error "Hypertrace Agent 下载失败"
            exit 1
        fi
        
        log_success "Hypertrace Agent 下载完成"
    else
        log_success "Hypertrace Agent 已存在"
    fi
}

# 创建配置文件
create_configs() {
    log_info "创建配置文件..."
    
    # 创建 Hypertrace 配置文件（如果不存在）
    if [ ! -f "hypertrace-config.yaml" ]; then
        cat > hypertrace-config.yaml << 'EOF'
# Hypertrace Agent 配置文件
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

reporting:
  endpoint: http://localhost:4317
  secure: false
EOF
        log_info "创建了 hypertrace-config.yaml"
    fi
    
    # Kafka 专用配置文件已移除，不再需要
}

# 启动服务
start_services() {
    log_info "启动 Hypertrace Demo 服务..."
    
    # 拉取最新镜像
    log_info "拉取 Docker 镜像..."
    $COMPOSE_CMD pull
    
    # 构建并启动服务
    log_info "构建并启动服务..."
    $COMPOSE_CMD up -d --build
    
    # 等待服务启动
    log_info "等待服务启动..."
    
    # 检查关键服务健康状态
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log_info "检查服务状态... ($attempt/$max_attempts)"
        
        # 检查 PostgreSQL
        if docker exec postgres pg_isready -U postgres &> /dev/null; then
            log_success "PostgreSQL 已就绪"
            break
        fi
        
        sleep 5
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        log_warning "服务启动检查超时，但继续进行..."
    fi
    
    # 显示服务状态
    log_info "服务状态:"
    $COMPOSE_CMD ps
}

# 验证安装
verify_installation() {
    log_info "验证安装..."
    
    # 等待应用完全启动
    sleep 10
    
    # 检查应用健康状态
    local app_url="http://localhost:8080"
    local max_attempts=20
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "$app_url/actuator/health" &> /dev/null || curl -s -f "$app_url" &> /dev/null; then
            log_success "应用服务验证通过"
            break
        fi
        
        log_info "等待应用启动... ($attempt/$max_attempts)"
        sleep 5
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        log_warning "应用服务验证超时，请检查日志"
    fi
    
    # 检查 Jaeger
    if curl -s -f "http://localhost:16686" &> /dev/null; then
        log_success "Jaeger UI 验证通过"
    else
        log_warning "Jaeger UI 可能未完全启动"
    fi
}

# 显示访问信息
show_access_info() {
    echo ""
    echo "================================================================"
    log_success "Hypertrace Demo 安装完成!"
    echo "================================================================"
    echo ""
    echo "🌐 服务访问地址:"
    echo "   Spring Boot 应用:     http://localhost:8080"
    echo "   Jaeger UI (追踪):     http://localhost:16686"
    echo "   脱敏配置管理界面:     http://localhost:3000"
    echo "   脱敏配置 API:         http://localhost:3001"
    echo ""
    echo "🗄️  数据库连接:"
    echo "   PostgreSQL:          localhost:5432 (postgres/password)"
    echo "   脱敏配置数据库:       localhost:55432 (sanitization_user/sanitization_pass_2024!)"
    echo ""
    echo "📨 消息队列:"
    echo "   Kafka:               localhost:9092"
    echo "   Zookeeper:           localhost:2181"
    echo ""
    echo "🧪 测试命令:"
    echo "   # 创建用户"
    echo "   curl -X POST http://localhost:8080/api/users \\"
    echo "        -H 'Content-Type: application/json' \\"
    echo "        -d '{\"name\":\"测试用户\",\"email\":\"test@example.com\"}'"
    echo ""
    echo "   # 触发 Kafka 通知"
    echo "   curl -X POST http://localhost:8080/api/users/1/notify"
    echo ""
    echo "🔧 管理命令:"
    echo "   # 查看所有服务日志"
    echo "   $COMPOSE_CMD logs -f"
    echo ""
    echo "   # 查看应用日志"
    echo "   $COMPOSE_CMD logs -f hypertrace-demo-app"
    echo ""
    echo "   # 重启服务"
    echo "   $COMPOSE_CMD restart"
    echo ""
    echo "   # 停止服务"
    echo "   $COMPOSE_CMD down"
    echo ""
    echo "   # 完全清理（包括数据卷）"
    echo "   $COMPOSE_CMD down -v"
    echo ""
    echo "📚 更多信息请查看 README.md"
    echo "================================================================"
}

# 清理函数
cleanup() {
    log_info "清理旧数据..."
    $COMPOSE_CMD down -v --remove-orphans 2>/dev/null || true
    docker system prune -f
    log_success "清理完成"
}

# 显示帮助信息
show_help() {
    echo "Hypertrace Demo 一键安装脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --help, -h     显示帮助信息"
    echo "  --clean        清理旧数据后安装"
    echo "  --check        仅检查系统要求"
    echo "  --verify       仅验证当前安装"
    echo "  --uninstall    卸载服务"
    echo ""
    echo "示例:"
    echo "  $0              # 标准安装"
    echo "  $0 --clean     # 清理后重新安装"
    echo "  $0 --check     # 检查系统要求"
}

# 卸载函数
uninstall() {
    echo "=== Hypertrace Demo 卸载 ==="
    
    read -p "确定要卸载 Hypertrace Demo 吗? 这将删除所有数据 (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "卸载已取消"
        exit 0
    fi
    
    log_info "停止并删除容器..."
    $COMPOSE_CMD down -v --remove-orphans
    
    log_info "删除相关镜像..."
    docker images | grep hypertrace-demo | awk '{print $3}' | xargs -r docker rmi -f 2>/dev/null || true
    
    log_info "清理未使用的 Docker 资源..."
    docker system prune -f
    
    log_success "卸载完成"
}

# 主安装流程
main() {
    check_requirements
    check_ports
    check_files
    create_configs
    start_services
    verify_installation
    show_access_info
}

# 处理命令行参数
case "${1:-}" in
    --help|-h)
        show_help
        exit 0
        ;;
    --clean)
        cleanup
        main
        ;;
    --check)
        check_requirements
        check_ports
        check_files
        log_success "系统检查完成，可以进行安装"
        exit 0
        ;;
    --verify)
        verify_installation
        exit 0
        ;;
    --uninstall)
        # 检查 Docker Compose 命令
        if command -v docker-compose &> /dev/null; then
            COMPOSE_CMD="docker-compose"
        elif docker compose version &> /dev/null; then
            COMPOSE_CMD="docker compose"
        else
            log_error "Docker Compose 未找到"
            exit 1
        fi
        uninstall
        exit 0
        ;;
    "")
        # 默认安装
        main
        ;;
    *)
        log_error "未知选项: $1"
        show_help
        exit 1
        ;;
esac