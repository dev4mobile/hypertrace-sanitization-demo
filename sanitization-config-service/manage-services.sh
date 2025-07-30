#!/bin/bash

# 脱敏管理系统服务管理脚本
# 支持：启动、停止、重启、查看状态、初始化数据库

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 函数：打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查Docker和docker-compose是否安装
check_requirements() {
    print_info "检查系统要求..."

    if ! command -v docker &> /dev/null; then
        print_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null; then
        print_error "docker-compose 未安装，请先安装 docker-compose"
        exit 1
    fi

    print_success "系统要求检查通过"
}

# 启动服务
start_services() {
    print_info "启动脱敏管理系统服务..."

    # 确保网络和卷存在
    docker network create sanitization-network 2>/dev/null || true

    # 启动服务
    docker-compose up -d

    print_info "等待服务启动..."
    sleep 10

    # 检查服务状态
    check_service_health
}

# 停止服务
stop_services() {
    print_info "停止脱敏管理系统服务..."
    docker-compose down
    print_success "服务已停止"
}

# 重启服务
restart_services() {
    print_info "重启脱敏管理系统服务..."
    docker-compose down
    sleep 5
    docker-compose up -d

    print_info "等待服务重启..."
    sleep 10

    check_service_health
}

# 检查服务健康状态
check_service_health() {
    print_info "检查服务健康状态..."

    # 检查数据库
    if docker-compose exec -T sanitization-postgres pg_isready -U sanitization_user -d sanitization_config >/dev/null 2>&1; then
        print_success "✅ 数据库服务正常"
    else
        print_error "❌ 数据库服务异常"
        return 1
    fi

    # 检查后端API
    sleep 5
    if curl -f http://localhost:3001/api/health >/dev/null 2>&1; then
        print_success "✅ 后端API服务正常"
    else
        print_warning "⚠️  后端API服务可能还在启动中，请稍等..."
        sleep 10
        if curl -f http://localhost:3001/api/health >/dev/null 2>&1; then
            print_success "✅ 后端API服务正常"
        else
            print_error "❌ 后端API服务异常"
        fi
    fi

    # 检查前端服务
    if curl -f http://localhost:3000 >/dev/null 2>&1; then
        print_success "✅ 前端服务正常"
    else
        print_warning "⚠️  前端服务可能还在启动中"
    fi

    print_success "服务启动完成！"
    echo ""
    echo "访问地址："
    echo "  🌐 前端管理界面: http://localhost:3000"
    echo "  🔌 后端API接口: http://localhost:3001"
    echo "  🗄️  数据库连接: localhost:55432"
    echo ""
}

# 查看服务状态
show_status() {
    print_info "服务运行状态："
    docker-compose ps

    echo ""
    print_info "容器资源使用情况："
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" $(docker-compose ps -q) 2>/dev/null || true
}

# 查看日志
show_logs() {
    local service=${1:-""}

    if [ -z "$service" ]; then
        print_info "显示所有服务日志（最近100行）"
        docker-compose logs --tail=100 -f
    else
        print_info "显示 $service 服务日志（最近100行）"
        docker-compose logs --tail=100 -f "$service"
    fi
}

# 初始化数据库
init_database() {
    print_info "初始化数据库..."

    # 确保数据库服务正在运行
    if ! docker-compose ps sanitization-postgres | grep -q "Up"; then
        print_error "数据库服务未运行，请先启动服务"
        exit 1
    fi

    # 运行数据库初始化脚本
    if docker-compose exec -T sanitization-backend node scripts/init-db.js; then
        print_success "数据库初始化完成"
    else
        print_error "数据库初始化失败"
        exit 1
    fi
}

# 备份数据库
backup_database() {
    local backup_file="backup_$(date +%Y%m%d_%H%M%S).sql"

    print_info "备份数据库到 $backup_file"

    if docker-compose exec -T sanitization-postgres pg_dump -U sanitization_user sanitization_config > "$backup_file"; then
        print_success "数据库备份完成: $backup_file"
    else
        print_error "数据库备份失败"
        exit 1
    fi
}

# 恢复数据库
restore_database() {
    local backup_file="$1"

    if [ -z "$backup_file" ] || [ ! -f "$backup_file" ]; then
        print_error "请提供有效的备份文件路径"
        exit 1
    fi

    print_warning "这将覆盖当前数据库，确定要继续吗？(y/N)"
    read -r confirm

    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        print_info "操作已取消"
        exit 0
    fi

    print_info "从 $backup_file 恢复数据库"

    if docker-compose exec -T sanitization-postgres psql -U sanitization_user -d sanitization_config < "$backup_file"; then
        print_success "数据库恢复完成"
    else
        print_error "数据库恢复失败"
        exit 1
    fi
}

# 清理数据
clean_data() {
    print_warning "这将删除所有数据库数据和Docker卷，确定要继续吗？(y/N)"
    read -r confirm

    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        print_info "操作已取消"
        exit 0
    fi

    print_info "停止服务并清理数据..."
    docker-compose down -v
    docker volume rm sanitization-postgres-data 2>/dev/null || true

    print_success "数据清理完成"
}

# 更新服务
update_services() {
    print_info "更新服务镜像..."
    docker-compose pull
    docker-compose up -d --force-recreate

    print_info "等待服务更新完成..."
    sleep 15

    check_service_health
}

# 显示帮助信息
show_help() {
    echo "脱敏管理系统服务管理脚本"
    echo ""
    echo "用法: $0 [命令] [参数]"
    echo ""
    echo "命令:"
    echo "  start       启动所有服务"
    echo "  stop        停止所有服务"
    echo "  restart     重启所有服务"
    echo "  status      查看服务状态"
    echo "  logs [服务] 查看日志 (可选择特定服务: postgres|backend|frontend)"
    echo "  health      检查服务健康状态"
    echo "  init-db     初始化数据库"
    echo "  backup      备份数据库"
    echo "  restore     恢复数据库"
    echo "  clean       清理所有数据"
    echo "  update      更新服务镜像"
    echo "  help        显示帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 start                    # 启动所有服务"
    echo "  $0 logs backend             # 查看后端服务日志"
    echo "  $0 restore backup.sql       # 从备份文件恢复数据库"
    echo ""
}

# 主逻辑
main() {
    local command=${1:-"help"}

    case $command in
        "start")
            check_requirements
            start_services
            ;;
        "stop")
            stop_services
            ;;
        "restart")
            check_requirements
            restart_services
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs "$2"
            ;;
        "health")
            check_service_health
            ;;
        "init-db")
            init_database
            ;;
        "backup")
            backup_database
            ;;
        "restore")
            restore_database "$2"
            ;;
        "clean")
            clean_data
            ;;
        "update")
            check_requirements
            update_services
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "未知命令: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"
