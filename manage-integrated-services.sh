#!/bin/bash

# 管理整合后的 Hypertrace 和脱敏配置服务
# 作者: Kiro AI Assistant

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 显示帮助信息
show_help() {
    echo -e "${BLUE}整合服务管理脚本${NC}"
    echo ""
    echo "用法: $0 [命令]"
    echo ""
    echo "可用命令:"
    echo "  start     - 启动所有服务"
    echo "  stop      - 停止所有服务"
    echo "  restart   - 重启所有服务"
    echo "  status    - 查看服务状态"
    echo "  logs      - 查看所有服务日志"
    echo "  logs-app  - 查看主应用日志"
    echo "  logs-san  - 查看脱敏配置服务日志"
    echo "  build     - 重新构建镜像"
    echo "  clean     - 清理所有容器和数据卷"
    echo "  health    - 检查服务健康状态"
    echo "  urls      - 显示服务访问地址"
    echo "  help      - 显示此帮助信息"
}

# 检查 Docker 环境
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker 未安装${NC}"
        exit 1
    fi
    
    if ! docker-compose version &> /dev/null && ! docker compose version &> /dev/null; then
        echo -e "${RED}❌ Docker Compose 未安装${NC}"
        exit 1
    fi
}

# 启动服务
start_services() {
    echo -e "${GREEN}🚀 启动所有服务...${NC}"
    docker-compose up -d
    echo -e "${GREEN}✅ 服务启动完成${NC}"
    show_urls
}

# 停止服务
stop_services() {
    echo -e "${YELLOW}🛑 停止所有服务...${NC}"
    docker-compose down
    echo -e "${GREEN}✅ 服务已停止${NC}"
}

# 重启服务
restart_services() {
    echo -e "${YELLOW}🔄 重启所有服务...${NC}"
    docker-compose restart
    echo -e "${GREEN}✅ 服务重启完成${NC}"
}

# 查看服务状态
show_status() {
    echo -e "${BLUE}📊 服务状态:${NC}"
    docker-compose ps
}

# 查看日志
show_logs() {
    case $1 in
        "app")
            echo -e "${BLUE}📋 主应用日志:${NC}"
            docker-compose logs -f hypertrace-sanitization-demo-app
            ;;
        "san")
            echo -e "${BLUE}📋 脱敏配置服务日志:${NC}"
            docker-compose logs -f sanitization-backend sanitization-frontend sanitization-postgres
            ;;
        *)
            echo -e "${BLUE}📋 所有服务日志:${NC}"
            docker-compose logs -f
            ;;
    esac
}

# 重新构建镜像
build_services() {
    echo -e "${BLUE}🔨 重新构建镜像...${NC}"
    docker-compose build --no-cache
    echo -e "${GREEN}✅ 镜像构建完成${NC}"
}

# 清理环境
clean_environment() {
    echo -e "${RED}🧹 清理所有容器和数据卷...${NC}"
    read -p "这将删除所有数据，确定继续吗？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker-compose down -v --remove-orphans
        docker system prune -f
        echo -e "${GREEN}✅ 清理完成${NC}"
    else
        echo -e "${YELLOW}❌ 操作已取消${NC}"
    fi
}

# 检查健康状态
check_health() {
    echo -e "${BLUE}🏥 检查服务健康状态...${NC}"
    
    services=("hypertrace-sanitization-demo-app:8080" "sanitization-backend:3001" "sanitization-frontend:3000" "jaeger:16686")
    
    for service in "${services[@]}"; do
        IFS=':' read -r name port <<< "$service"
        if curl -f -s "http://localhost:$port" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ $name (端口 $port) - 健康${NC}"
        else
            echo -e "${RED}❌ $name (端口 $port) - 不健康${NC}"
        fi
    done
}

# 显示服务访问地址
show_urls() {
    echo ""
    echo -e "${BLUE}📋 服务访问地址:${NC}"
    echo -e "  🔍 Jaeger UI (分布式追踪):     ${GREEN}http://localhost:16686${NC}"
    echo -e "  🏠 Hypertrace Demo App:       ${GREEN}http://localhost:8080${NC}"
    echo -e "  🛡️  脱敏配置管理界面:          ${GREEN}http://localhost:3000${NC}"
    echo -e "  🔧 脱敏配置 API:              ${GREEN}http://localhost:3001${NC}"
    echo -e "  🗄️  PostgreSQL (主数据库):     ${GREEN}localhost:5432${NC}"
    echo -e "  🗄️  PostgreSQL (脱敏配置):     ${GREEN}localhost:55432${NC}"
    echo -e "  📨 Kafka:                    ${GREEN}localhost:9092${NC}"
    echo ""
}

# 主逻辑
main() {
    check_docker
    
    case ${1:-help} in
        "start")
            start_services
            ;;
        "stop")
            stop_services
            ;;
        "restart")
            restart_services
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs
            ;;
        "logs-app")
            show_logs "app"
            ;;
        "logs-san")
            show_logs "san"
            ;;
        "build")
            build_services
            ;;
        "clean")
            clean_environment
            ;;
        "health")
            check_health
            ;;
        "urls")
            show_urls
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

main "$@"