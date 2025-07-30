#!/bin/bash

# 测试 Spring Boot 应用的 API 接口

BASE_URL="http://localhost:8080"

echo "=== 测试 Hypertrace Demo API ==="

# 等待应用启动
echo "等待应用启动..."
for i in {1..30}; do
    if curl -f -s "$BASE_URL/api/users" > /dev/null; then
        echo "应用已启动"
        break
    fi
    sleep 2
done

echo

# 1. 获取所有用户
echo "1. 获取所有用户"
curl -X GET "$BASE_URL/api/users" \
     -H "Content-Type: application/json" | jq .

echo -e "\n"

# 2. 创建新用户
echo "2. 创建新用户"
curl -X POST "$BASE_URL/api/users" \
     -H "Content-Type: application/json" \
     -d '{
       "name": "测试用户",
       "email": "test@example.com",
       "phone": "13800138000"
     }' | jq .

echo -e "\n"
sleep 1

# 2a. 通知用户 (这将触发 Kafka 消息)
echo "2a. 通知用户 ID=1 (触发 Kafka 消息)"
curl -X POST "$BASE_URL/api/users/1/notify" \
     -H "Content-Type: application/json"

echo -e "\n"

# 3. 获取特定用户
echo "3. 获取用户 ID=1"
curl -X GET "$BASE_URL/api/users/1" \
     -H "Content-Type: application/json" | jq .

echo -e "\n"

# 4. 更新用户
echo "4. 更新用户 ID=1"
curl -X PUT "$BASE_URL/api/users/1" \
     -H "Content-Type: application/json" \
     -d '{
       "name": "张三更新",
       "email": "zhangsan_updated@example.com",
       "phone": "13812345679"
     }' | jq .

echo -e "\n"

# 5. 模拟错误请求
echo "5. 模拟错误请求（获取不存在的用户）"
curl -X GET "$BASE_URL/api/users/999" \
     -H "Content-Type: application/json" -w "\nHTTP 状态码: %{http_code}\n"

echo -e "\n"

# 6. 检查应用健康状态
echo "6. 检查应用健康状态"
curl -X GET "$BASE_URL/actuator/health" \
     -H "Content-Type: application/json" | jq .

echo -e "\n"

# 7. 检查应用指标
echo "7. 检查应用指标"
curl -X GET "$BASE_URL/actuator/metrics" \
     -H "Content-Type: application/json" | jq .

echo -e "\n"

echo "=== API 测试完成 ==="
echo "访问以下地址查看监控数据："
echo "  - Jaeger UI: http://localhost:16686"
echo "  - Prometheus: http://localhost:9090"
echo "  - Grafana: http://localhost:3000 (admin/admin)"
echo "  - H2 Database: http://localhost:8080/h2-console"
