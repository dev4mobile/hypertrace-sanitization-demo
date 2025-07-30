#!/bin/bash

# Kerberos 环境设置脚本
# 使用方法: ./scripts/setup-kerberos.sh

echo "=== 设置 Kerberos 环境 ==="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查 Docker 是否运行
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}错误: Docker 未运行，请先启动 Docker${NC}"
    exit 1
fi

echo "1. 停止现有的 Kerberos 相关容器..."
docker-compose down kerberos-kdc kafka zookeeper 2>/dev/null || true

echo "2. 启动 Kerberos KDC 服务..."
docker-compose up -d kerberos-kdc

echo "3. 等待 KDC 服务启动..."
sleep 15

# 检查 KDC 是否启动成功
if ! docker-compose ps kerberos-kdc | grep -q "Up"; then
    echo -e "${RED}错误: KDC 服务启动失败${NC}"
    docker-compose logs kerberos-kdc
    exit 1
fi

echo -e "${GREEN}✓${NC} KDC 服务启动成功"

echo "4. 从 KDC 容器中提取 keytab 文件..."

# 创建本地 kerberos 目录（如果不存在）
mkdir -p ./kerberos

# 等待 keytab 文件生成
echo "等待 keytab 文件生成..."
for i in {1..30}; do
    if docker exec kerberos-kdc test -f /var/kerberos/kafka-client.keytab; then
        echo -e "${GREEN}✓${NC} Kafka 客户端 keytab 文件已生成"
        break
    fi
    echo "等待中... ($i/30)"
    sleep 2
done

# 复制 keytab 文件到本地
echo "复制 keytab 文件到本地..."
docker cp kerberos-kdc:/var/kerberos/kafka-client.keytab ./kerberos/kafka-client.keytab
docker cp kerberos-kdc:/var/kerberos/kafka.keytab ./kerberos/kafka.keytab

# 设置文件权限
chmod 600 ./kerberos/kafka-client.keytab
chmod 600 ./kerberos/kafka.keytab

echo -e "${GREEN}✓${NC} Keytab 文件已复制到本地"

echo "5. 验证 keytab 文件..."
if [ -f "./kerberos/kafka-client.keytab" ]; then
    echo -e "${GREEN}✓${NC} Kafka 客户端 keytab: ./kerberos/kafka-client.keytab"
    # 如果系统有 klist 命令，显示 keytab 内容
    if command -v klist >/dev/null 2>&1; then
        echo "Keytab 内容:"
        klist -kt ./kerberos/kafka-client.keytab
    fi
else
    echo -e "${RED}✗${NC} Kafka 客户端 keytab 文件不存在"
fi

if [ -f "./kerberos/kafka.keytab" ]; then
    echo -e "${GREEN}✓${NC} Kafka 服务 keytab: ./kerberos/kafka.keytab"
else
    echo -e "${RED}✗${NC} Kafka 服务 keytab 文件不存在"
fi

echo "6. 启动 Zookeeper 和 Kafka..."
docker-compose up -d zookeeper kafka

echo "7. 等待 Kafka 服务启动..."
sleep 20

# 检查 Kafka 是否启动成功
if ! docker-compose ps kafka | grep -q "Up"; then
    echo -e "${RED}错误: Kafka 服务启动失败${NC}"
    echo "查看 Kafka 日志:"
    docker-compose logs kafka
    exit 1
fi

echo -e "${GREEN}✓${NC} Kafka 服务启动成功"

echo "8. 验证 Kerberos 配置..."

# 显示 KDC 中的主体
echo "KDC 中的主体列表:"
docker exec kerberos-kdc kadmin.local -q "listprincs" | grep -E "(kafka|admin)"

echo ""
echo "=== Kerberos 环境设置完成 ==="
echo ""
echo -e "${YELLOW}接下来的步骤:${NC}"
echo "1. 运行测试: ./scripts/test-kerberos-config.sh"
echo "2. 启动应用: ./scripts/run-with-kerberos.sh"
echo "3. 测试 API: curl -X POST http://localhost:8080/api/users/1/notify"
echo ""
echo -e "${YELLOW}服务端口:${NC}"
echo "- Kerberos KDC: localhost:88"
echo "- Kafka (PLAINTEXT): localhost:9092"
echo "- Kafka (SASL_PLAINTEXT): localhost:9093"
echo "- Jaeger UI: http://localhost:16686"
echo ""
echo -e "${YELLOW}调试命令:${NC}"
echo "- 查看 KDC 日志: docker-compose logs kerberos-kdc"
echo "- 查看 Kafka 日志: docker-compose logs kafka"
echo "- 进入 KDC 容器: docker exec -it kerberos-kdc bash"
