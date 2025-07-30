#!/bin/bash

# 快速测试 Spring Boot 应用

echo "=== 开始快速测试 ==="

# 1. 运行单元测试
echo "1. 运行单元测试..."
./gradlew test

if [ $? -ne 0 ]; then
    echo "❌ 单元测试失败"
    exit 1
fi

echo "✅ 单元测试通过"

# 2. 构建应用
echo "2. 构建应用..."
./gradlew clean build -x test

if [ $? -ne 0 ]; then
    echo "❌ 构建失败"
    exit 1
fi

echo "✅ 构建成功"

# 3. 快速启动测试
echo "3. 启动应用进行快速测试..."

# 在后台启动应用
java -Dspring.profiles.active=dev \
     -jar build/libs/hypertrace-demo-0.0.1-SNAPSHOT.jar &

APP_PID=$!

# 等待应用启动
echo "等待应用启动..."
sleep 15

# 检查应用是否正在运行
if ! ps -p $APP_PID > /dev/null; then
    echo "❌ 应用启动失败"
    exit 1
fi

# 测试健康检查端点
echo "4. 测试健康检查端点..."
HEALTH_CHECK=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/actuator/health)

if [ "$HEALTH_CHECK" = "200" ]; then
    echo "✅ 健康检查通过"
else
    echo "❌ 健康检查失败，状态码: $HEALTH_CHECK"
    kill $APP_PID
    exit 1
fi

# 测试用户 API
echo "5. 测试用户 API..."
API_CHECK=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/users)

if [ "$API_CHECK" = "200" ]; then
    echo "✅ 用户 API 正常"
else
    echo "❌ 用户 API 失败，状态码: $API_CHECK"
    kill $APP_PID
    exit 1
fi

# 停止应用
echo "6. 停止应用..."
kill $APP_PID

echo "✅ 快速测试全部通过！"
echo ""
echo "=== 测试完成 ==="
echo "应用已准备就绪，可以使用以下命令启动："
echo "  ./scripts/run-without-agent.sh        # 不使用 Hypertrace Agent"
echo "  ./scripts/run-with-agent.sh          # 使用 Hypertrace Agent"
