#!/bin/bash

# 设置 Kerberos keytab 文件脚本
# 使用方法: ./scripts/setup-kerberos-keytabs.sh

echo "=== 设置 Kerberos Keytab 文件 ==="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查 KDC 容器是否运行
if ! docker ps | grep -q kerberos-kdc; then
    echo -e "${RED}错误: Kerberos KDC 容器未运行${NC}"
    echo "请先启动 KDC 容器: docker-compose up -d kerberos-kdc"
    exit 1
fi

echo -e "${GREEN}✓${NC} KDC 容器正在运行"

# 等待 KDC 服务完全启动
echo "等待 KDC 服务启动..."
sleep 10

# 检查 KDC 服务状态
echo "检查 KDC 服务状态..."
docker exec kerberos-kdc kadmin.local -q "listprincs" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}警告: KDC 服务可能还未完全启动，等待更长时间...${NC}"
    sleep 20
fi

# 从容器复制 keytab 文件
echo "从 KDC 容器复制 keytab 文件..."

# 复制 Kafka 客户端 keytab
if docker exec kerberos-kdc test -f /tmp/kafka-client.keytab; then
    docker cp kerberos-kdc:/tmp/kafka-client.keytab ./kerberos/kafka-client.keytab
    chmod 600 ./kerberos/kafka-client.keytab
    echo -e "${GREEN}✓${NC} 已复制 kafka-client.keytab"
else
    echo -e "${RED}✗${NC} kafka-client.keytab 不存在"
fi

# 复制 Kafka 服务器 keytab
if docker exec kerberos-kdc test -f /tmp/kafka.keytab; then
    docker cp kerberos-kdc:/tmp/kafka.keytab ./kerberos/kafka.keytab
    chmod 600 ./kerberos/kafka.keytab
    echo -e "${GREEN}✓${NC} 已复制 kafka.keytab"
else
    echo -e "${RED}✗${NC} kafka.keytab 不存在"
fi

# 验证 keytab 文件
echo ""
echo "验证 keytab 文件:"

if [ -f "./kerberos/kafka-client.keytab" ] && [ -s "./kerberos/kafka-client.keytab" ]; then
    echo -e "${GREEN}✓${NC} kafka-client.keytab 存在且非空"
    echo "  大小: $(ls -lh ./kerberos/kafka-client.keytab | awk '{print $5}')"
else
    echo -e "${RED}✗${NC} kafka-client.keytab 不存在或为空"
fi

if [ -f "./kerberos/kafka.keytab" ] && [ -s "./kerberos/kafka.keytab" ]; then
    echo -e "${GREEN}✓${NC} kafka.keytab 存在且非空"
    echo "  大小: $(ls -lh ./kerberos/kafka.keytab | awk '{print $5}')"
else
    echo -e "${RED}✗${NC} kafka.keytab 不存在或为空"
fi

# 显示 keytab 内容（如果可用）
if command -v klist >/dev/null 2>&1; then
    echo ""
    echo "Keytab 文件内容:"
    
    if [ -f "./kerberos/kafka-client.keytab" ] && [ -s "./kerberos/kafka-client.keytab" ]; then
        echo "kafka-client.keytab:"
        klist -kt ./kerberos/kafka-client.keytab
    fi
    
    if [ -f "./kerberos/kafka.keytab" ] && [ -s "./kerberos/kafka.keytab" ]; then
        echo "kafka.keytab:"
        klist -kt ./kerberos/kafka.keytab
    fi
else
    echo -e "${YELLOW}注意: klist 命令不可用，无法显示 keytab 内容${NC}"
fi

echo ""
echo -e "${GREEN}=== Kerberos Keytab 设置完成 ===${NC}"
echo ""
echo -e "${YELLOW}下一步:${NC}"
echo "1. 重启 Kafka 以加载新的 keytab 文件: docker-compose restart kafka"
echo "2. 运行应用: ./scripts/run-with-kerberos.sh"
