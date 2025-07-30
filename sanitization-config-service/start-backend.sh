#!/bin/bash

# 脱敏配置服务后端启动脚本
# Sanitization Config Service Backend Startup Script

set -e

echo "🚀 启动脱敏配置服务后端..."
echo "🔧 Starting Sanitization Config Service Backend..."

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查Node.js版本
check_node_version() {
    echo -e "${BLUE}📋 检查Node.js版本...${NC}"
    if ! command -v node &> /dev/null; then
        echo -e "${RED}❌ Node.js 未安装。请安装 Node.js 18+ 版本${NC}"
        exit 1
    fi

    NODE_VERSION=$(node -v | cut -d 'v' -f 2 | cut -d '.' -f 1)
    if [ "$NODE_VERSION" -lt 18 ]; then
        echo -e "${RED}❌ Node.js 版本过低。需要 Node.js 18+ 版本，当前版本: $(node -v)${NC}"
        exit 1
    fi

    echo -e "${GREEN}✅ Node.js 版本检查通过: $(node -v)${NC}"
}

# 进入后端目录
cd "$(dirname "$0")/server"

# 检查环境
check_node_version

# 检查是否存在package.json
if [ ! -f "package.json" ]; then
    echo -e "${RED}❌ package.json 文件不存在${NC}"
    exit 1
fi

# 安装依赖
echo -e "${BLUE}📦 安装后端依赖...${NC}"
if [ ! -d "node_modules" ] || [ "package.json" -nt "node_modules" ]; then
    npm install
    echo -e "${GREEN}✅ 依赖安装完成${NC}"
else
    echo -e "${YELLOW}📦 依赖已存在，跳过安装${NC}"
fi

# 创建数据目录
echo -e "${BLUE}📁 创建数据目录...${NC}"
mkdir -p ../data
echo -e "${GREEN}✅ 数据目录创建完成${NC}"

# 设置环境变量
export NODE_ENV=${NODE_ENV:-development}
export PORT=${PORT:-3001}
export DATA_DIR=${DATA_DIR:-../data}

echo -e "${BLUE}🔧 环境配置:${NC}"
echo -e "  📍 运行模式: ${NODE_ENV}"
echo -e "  🌐 端口: ${PORT}"
echo -e "  📁 数据目录: ${DATA_DIR}"

# 启动后端服务
echo -e "${GREEN}🚀 启动后端服务...${NC}"
echo -e "${BLUE}📡 服务地址: http://localhost:${PORT}${NC}"
echo -e "${BLUE}🔗 健康检查: http://localhost:${PORT}/api/health${NC}"
echo -e "${BLUE}📖 API文档: http://localhost:${PORT}/api${NC}"
echo ""
echo -e "${YELLOW}💡 提示: 按 Ctrl+C 停止服务${NC}"
echo ""

# 根据环境选择启动方式
if [ "$NODE_ENV" = "development" ]; then
    if command -v nodemon &> /dev/null; then
        echo -e "${BLUE}🔄 使用 nodemon 启动开发模式...${NC}"
        npm run dev
    else
        echo -e "${YELLOW}⚠️  nodemon 未安装，使用 node 启动...${NC}"
        npm start
    fi
else
    echo -e "${BLUE}🏭 启动生产模式...${NC}"
    npm start
fi
