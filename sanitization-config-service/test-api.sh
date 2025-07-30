#!/bin/bash

echo "=== Sanitization Config Service API 测试 ==="
echo

# 设置API基础URL
API_URL="http://localhost:3001"

echo "🔍 1. 测试健康检查..."
echo "GET $API_URL/api/health"
curl -s "$API_URL/api/health" | jq '.' || echo "健康检查失败"
echo
echo

echo "📊 2. 测试获取规则..."
echo "GET $API_URL/api/sanitization/rules"
curl -s "$API_URL/api/sanitization/rules" | jq '.' || echo "获取规则失败"
echo
echo

echo "⚙️ 3. 测试获取配置..."
echo "GET $API_URL/api/config"
curl -s "$API_URL/api/config" | jq '.' || echo "获取配置失败"
echo
echo

echo "📈 4. 测试获取统计..."
echo "GET $API_URL/api/metrics"
curl -s "$API_URL/api/metrics" | jq '.' || echo "获取统计失败"
echo
echo

echo "✅ API测试完成"
