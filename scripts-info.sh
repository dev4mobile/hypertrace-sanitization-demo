#!/bin/bash

# 脚本信息展示工具
# 显示项目中所有可用脚本的用途和使用方法

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}           Hypertrace Demo 脚本工具集${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""

# 主要脚本
echo -e "${GREEN}🚀 主要部署脚本${NC}"
echo -e "${CYAN}────────────────────────────────────────────────────────────────${NC}"

if [ -f "package.sh" ]; then
    echo -e "${YELLOW}📦 package.sh${NC} - 一键打包脚本"
    echo "   功能: 构建应用、下载依赖、创建分发包"
    echo "   用法: ./package.sh"
    echo "   输出: dist/hypertrace-sanitization-demo-1.0.0.tar.gz"
    echo ""
fi

if [ -f "install.sh" ]; then
    echo -e "${YELLOW}⚙️  install.sh${NC} - 一键安装脚本"
    echo "   功能: 环境检查、Docker Compose 部署、服务验证"
    echo "   用法: ./install.sh [选项]"
    echo "   选项:"
    echo "     --clean     清理后重新安装"
    echo "     --check     仅检查系统要求"
    echo "     --verify    验证当前安装"
    echo "     --uninstall 卸载服务"
    echo "     --help      显示帮助"
    echo ""
fi

if [ -f "test-deployment.sh" ]; then
    echo -e "${YELLOW}🧪 test-deployment.sh${NC} - 部署测试脚本"
    echo "   功能: 自动化测试部署结果、验证服务可用性"
    echo "   用法: ./test-deployment.sh"
    echo "   测试: API接口、数据库连接、Kafka服务、追踪数据"
    echo ""
fi

# 现有脚本
echo -e "${GREEN}🔧 现有工具脚本${NC}"
echo -e "${CYAN}────────────────────────────────────────────────────────────────${NC}"

if [ -f "scripts/run-docker.sh" ]; then
    echo -e "${YELLOW}🐳 scripts/run-docker.sh${NC} - Docker 环境启动"
    echo "   功能: 启动完整的 Docker 环境"
    echo "   用法: ./scripts/run-docker.sh [--clean]"
    echo ""
fi

if [ -f "Makefile" ]; then
    echo -e "${YELLOW}🛠️  Makefile${NC} - Make 构建工具"
    echo "   功能: 简化的构建和部署命令"
    echo "   用法: make deploy / make logs"
    echo ""
fi

# 配置文件
echo -e "${GREEN}📋 配置和文档${NC}"
echo -e "${CYAN}────────────────────────────────────────────────────────────────${NC}"

config_files=(
    "docker-compose.yml:Docker Compose 服务编排配置"
    "Dockerfile:Spring Boot 应用容器化配置"
    "hypertrace-config.yaml:Hypertrace Agent 配置"
    "DEPLOYMENT.md:详细部署指南"
    "QUICK_START.md:快速开始指南"
    "README.md:项目完整文档"
)

for config in "${config_files[@]}"; do
    file=$(echo "$config" | cut -d':' -f1)
    desc=$(echo "$config" | cut -d':' -f2)
    if [ -f "$file" ]; then
        echo -e "${YELLOW}📄 $file${NC} - $desc"
    fi
done

echo ""

# 使用建议
echo -e "${GREEN}💡 使用建议${NC}"
echo -e "${CYAN}────────────────────────────────────────────────────────────────${NC}"
echo -e "${PURPLE}新用户推荐流程:${NC}"
echo "1. 📖 阅读 QUICK_START.md 了解基本概念"
echo "2. 🔍 运行 ./install.sh --check 检查系统要求"
echo "3. 🚀 运行 ./install.sh 进行安装"
echo "4. 🧪 运行 ./test-deployment.sh 验证部署"
echo "5. 🌐 访问 http://localhost:8080 开始使用"
echo ""

echo -e "${PURPLE}开发者推荐流程:${NC}"
echo "1. 📦 运行 ./package.sh 创建分发包"
echo "2. 🔄 在测试环境解压并安装"
echo "3. 🔧 根据需要修改配置文件"
echo "4. 📊 查看 Jaeger UI 分析追踪数据"
echo ""

echo -e "${PURPLE}生产环境部署:${NC}"
echo "1. 📋 参考 DEPLOYMENT.md 生产环境指南"
echo "2. 🔒 修改默认密码和安全配置"
echo "3. 📈 配置监控和告警"
echo "4. 🔄 设置备份和恢复策略"
echo ""

# 快速命令参考
echo -e "${GREEN}⚡ 快速命令参考${NC}"
echo -e "${CYAN}────────────────────────────────────────────────────────────────${NC}"
echo -e "${YELLOW}部署相关:${NC}"
echo "  ./install.sh              # 标准安装"
echo "  ./install.sh --clean      # 清理重装"
echo "  ./test-deployment.sh      # 测试部署"
echo ""

echo -e "${YELLOW}服务管理:${NC}"
echo "  docker-compose ps         # 查看状态"
echo "  docker-compose logs -f    # 查看日志"
echo "  docker-compose restart    # 重启服务"
echo "  docker-compose down       # 停止服务"
echo ""

echo -e "${YELLOW}测试命令:${NC}"
echo "  curl http://localhost:8080/api/users  # 测试API"
echo "  curl -X POST http://localhost:8080/api/users/1/notify  # 测试Kafka"
echo ""

# 故障排除
echo -e "${GREEN}🆘 故障排除${NC}"
echo -e "${CYAN}────────────────────────────────────────────────────────────────${NC}"
echo -e "${RED}常见问题:${NC}"
echo "  端口被占用    → ./install.sh --clean"
echo "  服务启动失败  → docker-compose logs"
echo "  内存不足      → docker system prune -f"
echo "  配置错误      → 检查 docker-compose.yml"
echo ""

echo -e "${RED}获取帮助:${NC}"
echo "  ./install.sh --help       # 安装脚本帮助"
echo "  docker-compose --help     # Docker Compose 帮助"
echo "  查看项目 README.md        # 完整文档"
echo ""

echo -e "${BLUE}================================================================${NC}"
echo -e "${GREEN}🎯 目标: 让部署变得简单快捷！${NC}"
echo -e "${BLUE}================================================================${NC}"