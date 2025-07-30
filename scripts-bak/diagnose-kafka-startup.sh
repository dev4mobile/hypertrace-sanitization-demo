#!/bin/bash

# Kafka 启动问题诊断脚本
# 使用方法: ./scripts/diagnose-kafka-startup.sh

echo "=== Kafka 启动问题诊断 ==="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}1. 检查 Docker 服务状态${NC}"
docker-compose ps

echo ""
echo -e "${BLUE}2. 检查必要文件是否存在${NC}"

required_files=(
    "./agents/hypertrace-agent.jar"
    "./agents/jmx_prometheus_javaagent-0.20.0.jar"
    "./kafka-jmx-config.yml"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $file"
    else
        echo -e "${RED}✗${NC} $file (缺失)"
    fi
done

echo ""
echo -e "${BLUE}3. 检查网络连接${NC}"

# 检查 Zookeeper 连接
if nc -z localhost 2181 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Zookeeper (localhost:2181) 可访问"
else
    echo -e "${RED}✗${NC} Zookeeper (localhost:2181) 不可访问"
fi

# 检查 Jaeger 连接
if nc -z localhost 4317 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Jaeger OTLP (localhost:4317) 可访问"
else
    echo -e "${RED}✗${NC} Jaeger OTLP (localhost:4317) 不可访问"
fi

echo ""
echo -e "${BLUE}4. 停止并清理现有 Kafka 容器${NC}"
docker-compose stop kafka
docker-compose rm -f kafka

echo ""
echo -e "${BLUE}5. 重新启动 Kafka 服务${NC}"
echo "启动 Kafka..."
docker-compose up -d kafka

echo ""
echo -e "${BLUE}6. 等待 Kafka 启动并检查状态${NC}"
sleep 10

# 检查 Kafka 容器状态
if docker-compose ps kafka | grep -q "Up"; then
    echo -e "${GREEN}✓${NC} Kafka 容器正在运行"
    
    # 检查 Kafka 端口
    sleep 5
    if nc -z localhost 9092 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Kafka 端口 (9092) 可访问"
    else
        echo -e "${RED}✗${NC} Kafka 端口 (9092) 不可访问"
    fi
else
    echo -e "${RED}✗${NC} Kafka 容器启动失败"
fi

echo ""
echo -e "${BLUE}7. 查看 Kafka 日志${NC}"
echo "最近的 Kafka 日志:"
docker-compose logs --tail=20 kafka

echo ""
echo -e "${BLUE}8. 测试 Kafka 连接${NC}"
if nc -z localhost 9092 2>/dev/null; then
    echo -e "${GREEN}✓${NC} 可以连接到 Kafka"
    
    # 尝试创建测试主题
    echo "尝试创建测试主题..."
    docker exec kafka kafka-topics --create --topic test-topic --bootstrap-server localhost:9092 --partitions 1 --replication-factor 1 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} 成功创建测试主题"
        
        # 清理测试主题
        docker exec kafka kafka-topics --delete --topic test-topic --bootstrap-server localhost:9092 2>/dev/null
    else
        echo -e "${RED}✗${NC} 无法创建测试主题"
    fi
else
    echo -e "${RED}✗${NC} 无法连接到 Kafka"
fi

echo ""
echo -e "${BLUE}9. 诊断总结${NC}"

if docker-compose ps kafka | grep -q "Up" && nc -z localhost 9092 2>/dev/null; then
    echo -e "${GREEN}✓ Kafka 服务运行正常${NC}"
    echo ""
    echo -e "${YELLOW}接下来可以:${NC}"
    echo "1. 启动应用: ./scripts/run-kerberos-demo.sh"
    echo "2. 测试 API: curl -X POST http://localhost:8080/api/users/1/notify"
    echo "3. 查看追踪: http://localhost:16686"
else
    echo -e "${RED}✗ Kafka 服务存在问题${NC}"
    echo ""
    echo -e "${YELLOW}建议的修复步骤:${NC}"
    echo "1. 检查缺失的文件并下载必要的 agent"
    echo "2. 查看完整的 Kafka 日志: docker-compose logs kafka"
    echo "3. 检查 Docker 资源限制"
    echo "4. 重启 Docker 服务"
fi

echo ""
echo -e "${BLUE}10. 服务状态概览${NC}"
docker-compose ps
