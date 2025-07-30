#!/bin/bash

# 修复 Kafka Cluster ID 不匹配问题
# 使用方法: ./scripts/fix-kafka-cluster-id.sh

echo "=== 修复 Kafka Cluster ID 问题 ==="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}1. 停止所有服务${NC}"
docker-compose down

echo ""
echo -e "${BLUE}2. 清理 Kafka 和 Zookeeper 数据${NC}"
echo "清理 Docker volumes..."

# 删除相关的 Docker volumes
docker volume rm hypertrace-demo_kafka-data 2>/dev/null || true
docker volume rm hypertrace-demo_kerberos-data 2>/dev/null || true

echo -e "${GREEN}✓${NC} 数据清理完成"

echo ""
echo -e "${BLUE}3. 重新启动服务（按顺序）${NC}"

echo "启动 Jaeger 和 Postgres..."
docker-compose up -d jaeger postgres
sleep 5

echo "启动 Zookeeper..."
docker-compose up -d zookeeper
sleep 10

echo "启动 Kafka..."
docker-compose up -d kafka
sleep 15

echo ""
echo -e "${BLUE}4. 检查服务状态${NC}"
docker-compose ps

echo ""
echo -e "${BLUE}5. 等待 Kafka 完全启动${NC}"
echo "等待 Kafka 初始化..."

# 等待 Kafka 启动
for i in {1..30}; do
    if nc -z localhost 9092 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Kafka 端口可访问"
        break
    fi
    echo "等待中... ($i/30)"
    sleep 2
done

echo ""
echo -e "${BLUE}6. 验证 Kafka 功能${NC}"

if nc -z localhost 9092 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Kafka 连接成功"
    
    # 测试创建主题
    echo "测试创建主题..."
    if docker exec kafka kafka-topics --create --topic test-topic --bootstrap-server localhost:9092 --partitions 1 --replication-factor 1 2>/dev/null; then
        echo -e "${GREEN}✓${NC} 主题创建成功"
        
        # 列出主题
        echo "当前主题列表:"
        docker exec kafka kafka-topics --list --bootstrap-server localhost:9092
        
        # 清理测试主题
        docker exec kafka kafka-topics --delete --topic test-topic --bootstrap-server localhost:9092 2>/dev/null
        echo -e "${GREEN}✓${NC} 测试主题已清理"
    else
        echo -e "${RED}✗${NC} 主题创建失败"
    fi
else
    echo -e "${RED}✗${NC} Kafka 连接失败"
    echo "查看 Kafka 日志:"
    docker-compose logs --tail=10 kafka
fi

echo ""
echo -e "${BLUE}7. 最终状态检查${NC}"
docker-compose ps

if docker-compose ps kafka | grep -q "Up" && nc -z localhost 9092 2>/dev/null; then
    echo ""
    echo -e "${GREEN}🎉 Kafka 修复成功！${NC}"
    echo ""
    echo -e "${YELLOW}接下来可以:${NC}"
    echo "1. 启动演示应用: ./scripts/run-kerberos-demo.sh"
    echo "2. 测试 API: curl -X POST http://localhost:8080/api/users/1/notify"
    echo "3. 查看追踪: http://localhost:16686"
    echo "4. 查看服务状态: docker-compose ps"
else
    echo ""
    echo -e "${RED}❌ Kafka 仍有问题${NC}"
    echo ""
    echo -e "${YELLOW}进一步诊断:${NC}"
    echo "1. 查看完整日志: docker-compose logs kafka"
    echo "2. 检查系统资源: docker system df"
    echo "3. 重启 Docker: sudo systemctl restart docker"
fi
