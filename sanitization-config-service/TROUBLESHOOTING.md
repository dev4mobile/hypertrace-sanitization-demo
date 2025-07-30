# 脱敏配置服务故障排除指南

## 问题：API返回空数据

如果 `curl -s "http://localhost:3001/api/sanitization/rules"` 返回空数据，请按以下步骤排查：

### 1. 检查服务状态
```bash
docker-compose ps
```

### 2. 检查健康状态
```bash
curl -s "http://localhost:3001/api/health" | jq '.'
```

应该返回：
```json
{
  "status": "healthy",
  "checks": {
    "database": "healthy",
    "rules": "ready"
  },
  "stats": {
    "rulesCount": 4
  }
}
```

### 3. 检查数据库连接
```bash
# 连接到数据库容器
docker exec -it sanitization-postgres psql -U sanitization_user -d sanitization_config

# 检查表和数据
\dt
SELECT COUNT(*) FROM sanitization_rules;
SELECT id, name, enabled FROM sanitization_rules;
```

### 4. 查看后端日志
```bash
docker logs sanitization-backend
```

### 5. 完全重建服务
如果以上步骤都没有解决问题，运行重建脚本：
```bash
./restart-services.sh
```

## 常见问题

### 问题1：数据库连接失败
**症状**：健康检查返回 `database: "unhealthy"`
**解决方案**：
1. 检查PostgreSQL容器是否正常启动
2. 检查环境变量配置
3. 重建服务

### 问题2：规则数量为0
**症状**：健康检查返回 `rules: "no_data"`
**解决方案**：
1. 数据库初始化可能失败
2. 运行完全重建：`./restart-services.sh`

### 问题3：端口占用
**症状**：容器启动失败，提示端口被占用
**解决方案**：
```bash
# 查看端口占用
lsof -i :3001
lsof -i :5432

# 停止占用的进程或修改docker-compose.yml中的端口
```

## 手动测试API

使用提供的测试脚本：
```bash
./test-api.sh
```

或手动测试：
```bash
# 健康检查
curl -s "http://localhost:3001/api/health"

# 获取所有规则
curl -s "http://localhost:3001/api/sanitization/rules"

# 获取配置
curl -s "http://localhost:3001/api/config"

# 获取统计
curl -s "http://localhost:3001/api/metrics"
```

## 数据库直连测试

```bash
# 连接数据库
docker exec -it sanitization-postgres psql -U sanitization_user -d sanitization_config

# 验证数据
SELECT
    id,
    name,
    enabled,
    condition->>'type' as condition_type,
    action->>'algorithm' as action_algorithm
FROM sanitization_rules;
```

## 环境变量检查

确保以下环境变量正确设置：
```bash
# 在后端容器中检查
docker exec sanitization-backend env | grep DB_
```

应该看到：
```
DB_HOST=sanitization-postgres
DB_PORT=5432
DB_NAME=sanitization_config
DB_USER=sanitization_user
DB_PASSWORD=sanitization_pass_2024!
```

## 重置数据

如果需要完全重置数据：
```bash
# 停止服务并删除数据卷
docker-compose down -v
docker volume rm sanitization-postgres-data

# 重新启动
docker-compose up -d
```
