#!/bin/bash

# 一键打包脚本 - Hypertrace Demo 项目
# 将项目打包成可分发的压缩包

set -e

# 配置变量
PROJECT_NAME="hypertrace-demo"
VERSION="1.0.0"
PACKAGE_DIR="dist"
PACKAGE_NAME="${PROJECT_NAME}-${VERSION}"
ARCHIVE_NAME="${PACKAGE_NAME}.tar.gz"

echo "=== Hypertrace Demo 一键打包脚本 ==="
echo "项目名称: ${PROJECT_NAME}"
echo "版本: ${VERSION}"
echo "打包目录: ${PACKAGE_DIR}"

# 清理旧的打包目录
if [ -d "${PACKAGE_DIR}" ]; then
    echo "清理旧的打包目录..."
    rm -rf "${PACKAGE_DIR}"
fi

# 创建打包目录
echo "创建打包目录..."
mkdir -p "${PACKAGE_DIR}/${PACKAGE_NAME}"

# 检查必要文件
echo "检查必要文件..."
required_files=(
    "docker-compose.yml"
)

for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo "错误: 缺少必要文件 $file"
        exit 1
    fi
done

# 应用将通过 Docker 构建，无需预先构建 JAR 文件

# 保存 Docker 镜像
echo "保存 Docker 镜像到本地文件..."
mkdir -p "${PACKAGE_DIR}/${PACKAGE_NAME}/docker-images"

# 定义需要保存的镜像列表
docker_images=(
    "jaegertracing/all-in-one:latest"
    "confluentinc/cp-kafka:7.6.0"
    "postgres:16-alpine"
)

# 保存每个镜像
for image in "${docker_images[@]}"; do
    echo "正在保存镜像: $image"
    # 先拉取镜像确保是最新的
    docker pull "$image"
    # 保存镜像到 tar 文件
    image_file=$(echo "$image" | sed 's/[\/:]/_/g')
    docker save "$image" -o "${PACKAGE_DIR}/${PACKAGE_NAME}/docker-images/${image_file}.tar"
    echo "✓ 已保存: ${image_file}.tar"
done

# 构建本地应用镜像并保存
echo "构建并保存应用镜像..."
docker build -t hypertrace-demo-app:latest .
docker save hypertrace-demo-app:latest -o "${PACKAGE_DIR}/${PACKAGE_NAME}/docker-images/hypertrace-demo-app_latest.tar"

# 构建脱敏配置服务镜像
if [ -d "sanitization-config-service" ]; then
    echo "构建并保存脱敏配置服务镜像..."
    
    # 构建后端镜像
    if [ -d "sanitization-config-service/server" ]; then
        docker build -t sanitization-backend:latest sanitization-config-service/server
        docker save sanitization-backend:latest -o "${PACKAGE_DIR}/${PACKAGE_NAME}/docker-images/sanitization-backend_latest.tar"
    fi
    
    # 构建前端镜像
    docker build -t sanitization-frontend:latest sanitization-config-service
    docker save sanitization-frontend:latest -o "${PACKAGE_DIR}/${PACKAGE_NAME}/docker-images/sanitization-frontend_latest.tar"
fi

# 创建镜像清单文件
echo "创建镜像清单..."
cat > "${PACKAGE_DIR}/${PACKAGE_NAME}/docker-images/images.txt" << EOF
# Docker 镜像清单
# 格式: 镜像名称 -> 文件名

jaegertracing/all-in-one:latest -> jaegertracing_all-in-one_latest.tar
confluentinc/cp-kafka:7.6.0 -> confluentinc_cp-kafka_7.6.0.tar
postgres:16-alpine -> postgres_16-alpine.tar
hypertrace-demo-app:latest -> hypertrace-demo-app_latest.tar
sanitization-backend:latest -> sanitization-backend_latest.tar
sanitization-frontend:latest -> sanitization-frontend_latest.tar

# 总计: 6 个镜像
EOF

# 复制核心文件到打包目录
echo "复制项目文件..."
# 复制并修改 docker-compose.yml，将 build 配置替换为 image 配置
cp docker-compose.yml "${PACKAGE_DIR}/${PACKAGE_NAME}/"

# 修改 docker-compose.yml，将所有 build 配置替换为 image 配置
echo "修改 docker-compose.yml 配置..."

# 替换 hypertrace-demo-app 的 build 配置
sed -i.bak 's/build: \./image: hypertrace-demo-app:latest/' "${PACKAGE_DIR}/${PACKAGE_NAME}/docker-compose.yml"

# 替换 sanitization-backend 的 build 配置
sed -i.bak '/sanitization-backend:/,/container_name:/ {
    /build:/,/dockerfile: Dockerfile/ {
        s/build:/image: sanitization-backend:latest/
        /context:/d
        /dockerfile:/d
    }
}' "${PACKAGE_DIR}/${PACKAGE_NAME}/docker-compose.yml"

# 替换 sanitization-frontend 的 build 配置
sed -i.bak '/sanitization-frontend:/,/container_name:/ {
    /build:/,/dockerfile: Dockerfile/ {
        s/build:/image: sanitization-frontend:latest/
        /context:/d
        /dockerfile:/d
    }
}' "${PACKAGE_DIR}/${PACKAGE_NAME}/docker-compose.yml"

# 清理备份文件
rm -f "${PACKAGE_DIR}/${PACKAGE_NAME}/docker-compose.yml.bak"

cp README.md "${PACKAGE_DIR}/${PACKAGE_NAME}/"

# 复制 agents 目录
if [ -d "agents" ]; then
    cp -r agents "${PACKAGE_DIR}/${PACKAGE_NAME}/"
fi

# 复制 sanitization-config-service 目录（如果存在）
if [ -d "sanitization-config-service" ]; then
    cp -r sanitization-config-service "${PACKAGE_DIR}/${PACKAGE_NAME}/"
fi

# 创建安装脚本
cat > "${PACKAGE_DIR}/${PACKAGE_NAME}/install.sh" << 'EOF'
#!/bin/bash

# Hypertrace Demo 一键安装脚本
# 支持 Docker Compose 部署

set -e

echo "=== Hypertrace Demo 一键安装脚本 ==="

# 检查系统要求
check_requirements() {
    echo "检查系统要求..."

    # 检查 Docker
    if ! command -v docker &> /dev/null; then
        echo "错误: Docker 未安装"
        echo "请先安装 Docker: https://docs.docker.com/get-docker/"
        exit 1
    fi

    # 检查 Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo "错误: Docker Compose 未安装"
        echo "请先安装 Docker Compose: https://docs.docker.com/compose/install/"
        exit 1
    fi

    # 检查 Docker 服务状态
    if ! docker info &> /dev/null; then
        echo "错误: Docker 服务未运行"
        echo "请启动 Docker 服务"
        exit 1
    fi

    echo "✓ 系统要求检查通过"
}

# 检查端口占用
check_ports() {
    echo "检查端口占用..."

    ports=(10020 16686 9092 5432 3000 3001)
    occupied_ports=()

    for port in "${ports[@]}"; do
        if lsof -i :$port &> /dev/null; then
            occupied_ports+=($port)
        fi
    done

    if [ ${#occupied_ports[@]} -gt 0 ]; then
        echo "警告: 以下端口被占用: ${occupied_ports[*]}"
        echo "这可能会导致服务启动失败"
        read -p "是否继续安装? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "安装已取消"
            exit 1
        fi
    else
        echo "✓ 端口检查通过"
    fi
}

# 加载 Docker 镜像
load_docker_images() {
    echo "加载 Docker 镜像..."

    if [ -d "docker-images" ]; then
        for image_file in docker-images/*.tar; do
            if [ -f "$image_file" ]; then
                echo "正在加载镜像: $(basename "$image_file")"
                docker load -i "$image_file"
            fi
        done
        echo "✓ Docker 镜像加载完成"
    else
        echo "警告: 未找到 docker-images 目录，将从网络拉取镜像"
    fi
}

# 启动服务
start_services() {
    echo "启动 Hypertrace Demo 服务..."

    # 使用 docker-compose 或 docker compose
    if command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    else
        COMPOSE_CMD="docker compose"
    fi

    # 加载 Docker 镜像
    load_docker_images

    # 启动服务（不需要 --build 因为镜像已经加载）
    $COMPOSE_CMD up -d

    echo "等待服务启动..."
    sleep 30

    # 检查服务状态
    echo "检查服务状态..."
    $COMPOSE_CMD ps
}

# 显示访问信息
show_access_info() {
    echo ""
    echo "=== 安装完成 ==="
    echo "服务访问地址:"
    echo "  🌐 Spring Boot 应用:     http://localhost:10020"
    echo "  📊 Jaeger UI (追踪):     http://localhost:16686"
    echo "  🎛️  脱敏配置管理界面:     http://localhost:3000"
    echo "  🔧 脱敏配置 API:         http://localhost:3001"
    echo "  📨 Kafka (KRaft):       localhost:9092"
    echo ""
    echo "测试命令:"
    echo "  # 创建用户"
    echo "  curl -X POST http://localhost:10020/api/users \\"
    echo "       -H 'Content-Type: application/json' \\"
    echo "       -d '{\"name\":\"测试用户\",\"email\":\"test@example.com\"}'"
    echo ""
    echo "  # 触发 Kafka 通知"
    echo "  curl -X POST http://localhost:10020/api/users/1/notify"
    echo ""
    echo "管理命令:"
    echo "  # 查看日志"
    echo "  docker-compose logs -f hypertrace-demo-app"
    echo ""
    echo "  # 停止服务"
    echo "  docker-compose down"
    echo ""
    echo "  # 完全清理（包括数据卷）"
    echo "  docker-compose down -v"
    echo ""
    echo "  # 单独加载 Docker 镜像"
    echo "  ./load-images.sh"
}

# 主安装流程
main() {
    check_requirements
    check_ports
    start_services
    show_access_info
}

# 处理命令行参数
case "${1:-}" in
    --help|-h)
        echo "用法: $0 [选项]"
        echo "选项:"
        echo "  --help, -h     显示帮助信息"
        echo "  --clean        清理旧数据后安装"
        echo "  --check        仅检查系统要求"
        exit 0
        ;;
    --clean)
        echo "清理旧数据..."
        if command -v docker-compose &> /dev/null; then
            docker-compose down -v --remove-orphans 2>/dev/null || true
        else
            docker compose down -v --remove-orphans 2>/dev/null || true
        fi
        docker system prune -f
        ;;
    --check)
        check_requirements
        check_ports
        echo "系统检查完成"
        exit 0
        ;;
esac

# 执行主安装流程
main
EOF

# 给安装脚本执行权限
chmod +x "${PACKAGE_DIR}/${PACKAGE_NAME}/install.sh"

# 创建镜像加载脚本
cat > "${PACKAGE_DIR}/${PACKAGE_NAME}/load-images.sh" << 'EOF'
#!/bin/bash

# Docker 镜像加载脚本
# 用于离线环境加载预打包的 Docker 镜像

set -e

echo "=== Docker 镜像加载脚本 ==="

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo "错误: Docker 未安装"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "错误: Docker 服务未运行"
    exit 1
fi

# 检查镜像目录
if [ ! -d "docker-images" ]; then
    echo "错误: 未找到 docker-images 目录"
    exit 1
fi

# 加载所有镜像
echo "开始加载 Docker 镜像..."
loaded_count=0
total_count=$(ls docker-images/*.tar 2>/dev/null | wc -l)

for image_file in docker-images/*.tar; do
    if [ -f "$image_file" ]; then
        echo "正在加载: $(basename "$image_file")"
        if docker load -i "$image_file"; then
            ((loaded_count++))
            echo "✓ 加载成功"
        else
            echo "✗ 加载失败: $(basename "$image_file")"
        fi
    fi
done

echo ""
echo "=== 加载完成 ==="
echo "成功加载: $loaded_count/$total_count 个镜像"

# 显示已加载的镜像
echo ""
echo "已加载的镜像:"
docker images | grep -E "(jaegertracing|confluentinc|postgres|hypertrace-demo-app)" || echo "未找到相关镜像"
EOF

chmod +x "${PACKAGE_DIR}/${PACKAGE_NAME}/load-images.sh"

# 创建卸载脚本
cat > "${PACKAGE_DIR}/${PACKAGE_NAME}/uninstall.sh" << 'EOF'
#!/bin/bash

# Hypertrace Demo 卸载脚本

set -e

echo "=== Hypertrace Demo 卸载脚本 ==="

# 确认卸载
read -p "确定要卸载 Hypertrace Demo 吗? 这将删除所有数据 (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "卸载已取消"
    exit 0
fi

# 停止并删除容器
echo "停止并删除容器..."
if command -v docker-compose &> /dev/null; then
    docker-compose down -v --remove-orphans
else
    docker compose down -v --remove-orphans
fi

# 删除镜像
echo "删除相关镜像..."
docker images | grep hypertrace-demo | awk '{print $3}' | xargs -r docker rmi -f

# 清理未使用的资源
echo "清理未使用的 Docker 资源..."
docker system prune -f

echo "✓ 卸载完成"
EOF

chmod +x "${PACKAGE_DIR}/${PACKAGE_NAME}/uninstall.sh"

# 创建版本信息文件
cat > "${PACKAGE_DIR}/${PACKAGE_NAME}/VERSION" << EOF
项目名称: ${PROJECT_NAME}
版本: ${VERSION}
打包时间: $(date '+%Y-%m-%d %H:%M:%S')
打包环境: $(uname -s) $(uname -m)
Java 版本: $(java -version 2>&1 | head -n 1)
EOF

# 创建打包清单
echo "创建打包清单..."
find "${PACKAGE_DIR}/${PACKAGE_NAME}" -type f | sort > "${PACKAGE_DIR}/${PACKAGE_NAME}/MANIFEST.txt"

# 创建压缩包
echo "创建压缩包..."
cd "${PACKAGE_DIR}"
tar -czf "${ARCHIVE_NAME}" "${PACKAGE_NAME}"
cd ..

# 计算校验和
echo "计算校验和..."
cd "${PACKAGE_DIR}"
sha256sum "${ARCHIVE_NAME}" > "${ARCHIVE_NAME}.sha256"
cd ..

# 显示打包结果
echo ""
echo "=== 打包完成 ==="
echo "打包文件: ${PACKAGE_DIR}/${ARCHIVE_NAME}"
echo "文件大小: $(du -h "${PACKAGE_DIR}/${ARCHIVE_NAME}" | cut -f1)"
echo "校验文件: ${PACKAGE_DIR}/${ARCHIVE_NAME}.sha256"
echo ""
echo "安装方法:"
echo "1. 解压: tar -xzf ${ARCHIVE_NAME}"
echo "2. 进入目录: cd ${PACKAGE_NAME}"
echo "3. 运行安装: ./install.sh"
echo ""
echo "打包内容:"
echo "- Docker Compose 配置"
echo "- Hypertrace Agent"
echo "- 脱敏配置服务"
echo "- Docker 镜像文件 (离线部署)"
echo "- 一键安装/卸载脚本"
echo "- 项目文档"
echo ""
echo "Docker 镜像:"
echo "- jaegertracing/all-in-one:latest"
echo "- confluentinc/cp-kafka:7.6.0 (KRaft 模式)"
echo "- postgres:16-alpine"
echo "- hypertrace-demo-app:latest"
echo "- sanitization-backend:latest"
echo "- sanitization-frontend:latest"

echo "✓ 打包流程完成"
