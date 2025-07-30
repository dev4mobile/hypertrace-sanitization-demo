#!/bin/bash

# 验证 JDBC 数据采集是否已被禁用的脚本

echo "=== 验证 JDBC 数据采集禁用状态 ==="
echo ""

# 发送测试请求
echo "1. 发送测试请求..."
for i in {1..3}; do
    echo "  发送请求 $i..."
    curl -s -X POST http://localhost:8080/api/users/$i/notify > /dev/null
    sleep 1
done

echo ""
echo "2. 等待追踪数据传输..."
sleep 5

echo ""
echo "3. 检查 Jaeger 中的服务..."

# 获取服务列表
services=$(curl -s "http://localhost:16686/api/services" | jq -r '.data[]' 2>/dev/null)

if [ -n "$services" ]; then
    echo "✓ 发现的服务:"
    echo "$services" | while read service; do
        echo "  - $service"
    done
    
    # 检查是否有我们的服务
    if echo "$services" | grep -q "hypertrace-demo-app"; then
        echo ""
        echo "4. 获取最近的追踪数据..."
        
        # 获取最近的追踪数据
        traces=$(curl -s "http://localhost:16686/api/traces?service=hypertrace-demo-app&limit=5" 2>/dev/null)
        
        if [ -n "$traces" ]; then
            # 检查是否包含 JDBC spans
            jdbc_spans=$(echo "$traces" | jq -r '.data[].spans[] | select(.operationName | contains("SELECT") or contains("INSERT") or contains("UPDATE") or contains("DELETE") or contains("jdbc") or contains("hibernate") or contains("jpa")) | .operationName' 2>/dev/null)
            
            echo ""
            echo "5. JDBC 数据采集验证结果:"
            if [ -n "$jdbc_spans" ]; then
                echo "❌ 发现 JDBC 相关的 spans:"
                echo "$jdbc_spans" | while read span; do
                    echo "  - $span"
                done
                echo ""
                echo "⚠️  JDBC 数据采集仍然启用！"
            else
                echo "✅ 未发现 JDBC 相关的 spans"
                echo "✅ JDBC 数据采集已成功禁用！"
            fi
            
            echo ""
            echo "6. 发现的 spans 类型:"
            all_spans=$(echo "$traces" | jq -r '.data[].spans[].operationName' 2>/dev/null | sort | uniq)
            echo "$all_spans" | while read span; do
                echo "  - $span"
            done
            
        else
            echo "❌ 无法获取追踪数据"
        fi
    else
        echo "❌ 未找到 hypertrace-demo-app 服务"
    fi
else
    echo "❌ 无法获取服务列表"
fi

echo ""
echo "7. 访问 Jaeger UI 进行手动验证:"
echo "   http://localhost:16686"
echo "   - 选择服务: hypertrace-demo-app"
echo "   - 查找操作: 应该只看到 HTTP 和 Kafka 相关的 spans"
echo "   - 不应该看到: SELECT、INSERT、UPDATE、DELETE 等数据库操作"

echo ""
echo "=== 验证完成 ==="
