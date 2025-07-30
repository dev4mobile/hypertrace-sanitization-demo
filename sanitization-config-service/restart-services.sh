#!/bin/bash

echo "🔄 重建脱敏配置服务..."
echo

# 停止并删除现有容器和卷
echo "⏹️ 停止现有服务..."
docker-compose down -v

echo "🗑️ 清理数据卷..."
docker volume rm sanitization-postgres-data 2>/dev/null || true
docker volume rm sanitization-logs 2>/dev/null || true

echo "🧹 清理网络..."
docker network rm sanitization_sanitization-network 2>/dev/null || true

echo "🏗️ 重新构建并启动服务..."
docker-compose up --build -d

echo "⏳ 等待服务启动..."
sleep 10

echo "🔍 检查服务状态..."
docker-compose ps

echo "📊 检查后端健康状态..."
timeout 30s bash -c '
while ! curl -s http://localhost:3001/api/health > /dev/null; do
  echo "等待后端服务..."
  sleep 2
done
echo "✅ 后端服务已就绪"
'

echo "📋 测试API端点..."
curl -s "http://localhost:3001/api/sanitization/rules" | jq '.' > /dev/null && echo "✅ 规则API工作正常" || echo "❌ 规则API异常"

echo
echo "🎉 服务重建完成！"
echo "🔗 后端API: http://localhost:3001"
echo "🌐 前端界面: http://localhost:3000"
echo "📊 健康检查: http://localhost:3001/api/health"
echo "📋 规则API: http://localhost:3001/api/sanitization/rules"
