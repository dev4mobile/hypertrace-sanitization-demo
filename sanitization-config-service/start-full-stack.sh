#!/bin/bash

# 脱敏配置服务全栈启动脚本
# Sanitization Config Service Full Stack Startup Script

set -e

echo "🚀 启动脱敏配置服务全栈..."
echo "🔧 Starting Sanitization Config Service Full Stack..."

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 检查依赖
check_dependencies() {
    echo -e "${BLUE}📋 检查依赖...${NC}"

    # 检查Node.js
    if ! command -v node &> /dev/null; then
        echo -e "${RED}❌ Node.js 未安装。请安装 Node.js 18+ 版本${NC}"
        exit 1
    fi

    NODE_VERSION=$(node -v | cut -d 'v' -f 2 | cut -d '.' -f 1)
    if [ "$NODE_VERSION" -lt 18 ]; then
        echo -e "${RED}❌ Node.js 版本过低。需要 Node.js 18+ 版本，当前版本: $(node -v)${NC}"
        exit 1
    fi

    echo -e "${GREEN}✅ Node.js 版本: $(node -v)${NC}"

    # 检查npm
    if ! command -v npm &> /dev/null; then
        echo -e "${RED}❌ npm 未安装${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ npm 版本: $(npm -v)${NC}"

    # 检查Docker和Docker Compose
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker 未安装。请安装 Docker${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Docker 版本: $(docker --version)${NC}"

    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo -e "${RED}❌ Docker Compose 未安装。请安装 Docker Compose${NC}"
        exit 1
    fi

    if command -v docker-compose &> /dev/null; then
        echo -e "${GREEN}✅ Docker Compose 版本: $(docker-compose --version)${NC}"
    else
        echo -e "${GREEN}✅ Docker Compose 版本: $(docker compose version)${NC}"
    fi
}

# 安装依赖
install_dependencies() {
    echo -e "${BLUE}📦 安装项目依赖...${NC}"

    # 安装前端依赖
    echo -e "${PURPLE}🎨 安装前端依赖...${NC}"
    if [ ! -d "node_modules" ] || [ "package.json" -nt "node_modules" ]; then
        npm install
        echo -e "${GREEN}✅ 前端依赖安装完成${NC}"
    else
        echo -e "${YELLOW}📦 前端依赖已存在，跳过安装${NC}"
    fi

    # 安装后端依赖
    echo -e "${PURPLE}⚙️  安装后端依赖...${NC}"
    cd server
    if [ ! -d "node_modules" ] || [ "package.json" -nt "node_modules" ]; then
        npm install
        echo -e "${GREEN}✅ 后端依赖安装完成${NC}"
    else
        echo -e "${YELLOW}📦 后端依赖已存在，跳过安装${NC}"
    fi
    cd ..
}

# 创建必要目录
setup_directories() {
    echo -e "${BLUE}📁 创建必要目录...${NC}"
    mkdir -p logs
    echo -e "${GREEN}✅ 目录创建完成${NC}"
}

# 启动数据库服务
start_database() {
    echo -e "${BLUE}🗄️  启动 PostgreSQL 数据库...${NC}"

    # 检查数据库是否已经在运行
    if docker ps | grep -q "sanitization-postgres"; then
        echo -e "${YELLOW}📦 PostgreSQL 数据库已在运行${NC}"
        return 0
    fi

    # 使用Docker Compose启动PostgreSQL
    if command -v docker-compose &> /dev/null; then
        docker-compose up -d sanitization-postgres
    else
        docker compose up -d sanitization-postgres
    fi

    # 等待数据库启动
    echo -e "${YELLOW}⏳ 等待数据库启动...${NC}"
    for i in {1..60}; do
        if docker exec sanitization-postgres pg_isready -U sanitization_user -d sanitization_config > /dev/null 2>&1; then
            echo -e "${GREEN}✅ PostgreSQL 数据库启动成功${NC}"
            break
        fi
        if [ $i -eq 60 ]; then
            echo -e "${RED}❌ 数据库启动超时${NC}"
            exit 1
        fi
        sleep 1
    done

    # 初始化数据库（如果需要）
    echo -e "${BLUE}🔧 检查数据库初始化状态...${NC}"
    sleep 2

    # 检查是否需要初始化数据库
    cd server
    if npm run db:init > ../logs/db-init.log 2>&1; then
        echo -e "${GREEN}✅ 数据库初始化完成${NC}"
    else
        echo -e "${YELLOW}⚠️  数据库初始化可能已完成或遇到问题，请检查日志${NC}"
    fi
    cd ..
}

# 清理函数
cleanup() {
    echo -e "\n${YELLOW}🛑 正在关闭服务...${NC}"
    if [ ! -z "$BACKEND_PID" ]; then
        echo -e "${BLUE}⏹️  关闭后端服务 (PID: $BACKEND_PID)${NC}"
        kill $BACKEND_PID 2>/dev/null || true
    fi
    if [ ! -z "$FRONTEND_PID" ]; then
        echo -e "${BLUE}⏹️  关闭前端服务 (PID: $FRONTEND_PID)${NC}"
        kill $FRONTEND_PID 2>/dev/null || true
    fi

    # 询问是否关闭数据库
    echo -e "${YELLOW}❓ 是否关闭 PostgreSQL 数据库? [y/N]${NC}"
    read -t 10 -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}⏹️  关闭 PostgreSQL 数据库...${NC}"
        if command -v docker-compose &> /dev/null; then
            docker-compose stop sanitization-postgres
        else
            docker compose stop sanitization-postgres
        fi
        echo -e "${GREEN}✅ 数据库已关闭${NC}"
    else
        echo -e "${YELLOW}📦 PostgreSQL 数据库保持运行${NC}"
    fi

    echo -e "${GREEN}✅ 服务已关闭${NC}"
    exit 0
}

# 设置信号处理
trap cleanup SIGINT SIGTERM

# 主函数
main() {
    echo -e "${PURPLE}========================= 🏗️  环境准备 =========================${NC}"
    check_dependencies
    install_dependencies
    setup_directories

    echo -e "\n${PURPLE}========================= 🗄️  数据库启动 =========================${NC}"
    start_database

    echo -e "\n${PURPLE}========================= 🚀 启动服务 =========================${NC}"

    # 设置环境变量
    export NODE_ENV=${NODE_ENV:-development}
    export REACT_APP_API_URL=${REACT_APP_API_URL:-http://localhost:3001}
    export REACT_APP_USE_BACKEND=${REACT_APP_USE_BACKEND:-true}

    # 数据库环境变量
    export DB_HOST=${DB_HOST:-localhost}
    export DB_PORT=${DB_PORT:-55432}
    export DB_NAME=${DB_NAME:-sanitization_config}
    export DB_USER=${DB_USER:-sanitization_user}
    export DB_PASSWORD=${DB_PASSWORD:-sanitization_pass_2024!}
    export DB_SSL=${DB_SSL:-false}

    echo -e "${BLUE}🔧 环境配置:${NC}"
    echo -e "  📍 运行模式: ${NODE_ENV}"
    echo -e "  🌐 前端地址: http://localhost:3000"
    echo -e "  ⚙️  后端地址: http://localhost:3001"
    echo -e "  🔗 API连接: ${REACT_APP_API_URL}"
    echo -e "  🗄️  数据库: ${DB_HOST}:${DB_PORT}/${DB_NAME}"
    echo ""

    # 启动后端服务
    echo -e "${BLUE}⚙️  启动后端服务...${NC}"
    cd server
    if [ "$NODE_ENV" = "development" ] && command -v nodemon &> /dev/null; then
        npm run dev > ../logs/backend.log 2>&1 &
    else
        npm start > ../logs/backend.log 2>&1 &
    fi
    BACKEND_PID=$!
    cd ..

    # 等待后端服务启动
    echo -e "${YELLOW}⏳ 等待后端服务启动...${NC}"
    for i in {1..30}; do
        if curl -s http://localhost:3001/api/health > /dev/null 2>&1; then
            echo -e "${GREEN}✅ 后端服务启动成功 (PID: $BACKEND_PID)${NC}"
            break
        fi
        if [ $i -eq 30 ]; then
            echo -e "${RED}❌ 后端服务启动超时${NC}"
            exit 1
        fi
        sleep 1
    done

    # 启动前端服务
    echo -e "${BLUE}🎨 启动前端服务...${NC}"
    BROWSER=none npm start > logs/frontend.log 2>&1 &
    FRONTEND_PID=$!

    # 等待前端服务启动
    echo -e "${YELLOW}⏳ 等待前端服务启动...${NC}"
    for i in {1..60}; do
        if curl -s http://localhost:3000 > /dev/null 2>&1; then
            echo -e "${GREEN}✅ 前端服务启动成功 (PID: $FRONTEND_PID)${NC}"
            break
        fi
        if [ $i -eq 60 ]; then
            echo -e "${RED}❌ 前端服务启动超时${NC}"
            exit 1
        fi
        sleep 1
    done

    echo -e "\n${PURPLE}========================= 🎉 启动完成 =========================${NC}"
    echo -e "${GREEN}🌟 脱敏配置服务全栈启动成功！${NC}"
    echo ""
    echo -e "${BLUE}📱 访问地址:${NC}"
    echo -e "  🎨 前端管理界面: ${GREEN}http://localhost:3000${NC}"
    echo -e "  ⚙️  后端API服务: ${GREEN}http://localhost:3001${NC}"
    echo -e "  🔗 健康检查: ${GREEN}http://localhost:3001/api/health${NC}"
    echo -e "  📊 服务指标: ${GREEN}http://localhost:3001/api/metrics${NC}"
    echo ""
    echo -e "${BLUE}📋 进程信息:${NC}"
    echo -e "  ⚙️  后端服务 PID: ${BACKEND_PID}"
    echo -e "  🎨 前端服务 PID: ${FRONTEND_PID}"
    echo ""
    echo -e "${BLUE}📝 日志文件:${NC}"
    echo -e "  ⚙️  后端日志: logs/backend.log"
    echo -e "  🎨 前端日志: logs/frontend.log"
    echo ""
    echo -e "${YELLOW}💡 提示:${NC}"
    echo -e "  • 按 ${RED}Ctrl+C${NC} 停止所有服务"
    echo -e "  • 使用 ${GREEN}tail -f logs/backend.log${NC} 查看后端日志"
    echo -e "  • 使用 ${GREEN}tail -f logs/frontend.log${NC} 查看前端日志"
    echo ""

    # 保持脚本运行
    echo -e "${BLUE}🔄 服务运行中，等待信号...${NC}"
    wait
}

# 执行主函数
main
