# 脱敏配置服务 API 文档

## 概述

脱敏配置服务提供了完整的REST API来管理数据脱敏规则。API支持CRUD操作、批量操作、健康检查等功能。

## 基础信息

- **基础URL**: `http://localhost:3001`
- **内容类型**: `application/json`
- **认证**: 暂不需要（可根据需求添加）

## API 端点

### 健康检查

#### GET /api/health

检查服务健康状态

**响应示例:**
```json
{
  "status": "healthy",
  "timestamp": "2025-07-22T05:09:37.082Z",
  "version": "1.0.0",
  "uptime": 7.324035083,
  "checks": {
    "storage": "healthy",
    "memory": "healthy"
  }
}
```

### 配置管理

#### GET /api/config

获取完整的脱敏配置

**响应示例:**
```json
{
  "success": true,
  "data": {
    "enabled": true,
    "version": "1.0.0",
    "timestamp": 1753160969863,
    "rules": [...]
  },
  "timestamp": 1753160982906
}
```

### 规则管理

#### GET /api/rules

获取所有脱敏规则

**查询参数:**
- `enabled` (可选): `true` | `false` - 过滤启用/禁用的规则

**响应示例:**
```json
{
  "success": true,
  "data": [
    {
      "id": "rule_001",
      "name": "手机号脱敏",
      "description": "对手机号进行脱敏处理，保留前3位和后4位",
      "enabled": true,
      "priority": 10,
      "category": "personal_info",
      "sensitivity": "medium",
      "condition": {
        "type": "regex",
        "pattern": "^1[3-9]\\d{9}$"
      },
      "action": {
        "algorithm": "mask",
        "params": {
          "maskChar": "*",
          "prefix": 3,
          "suffix": 4
        }
      },
      "metadata": {
        "createdAt": "2025-07-22T05:09:29.863Z",
        "updatedAt": "2025-07-22T05:09:29.863Z",
        "version": "1.0",
        "author": "system"
      }
    }
  ],
  "total": 3,
  "timestamp": 1753160984313
}
```

#### GET /api/rules/:id

获取特定规则

**路径参数:**
- `id`: 规则ID

**响应示例:**
```json
{
  "success": true,
  "data": {
    "id": "rule_001",
    "name": "手机号脱敏",
    ...
  },
  "timestamp": 1753160984313
}
```

#### POST /api/rules

创建新规则

**请求体:**
```json
{
  "name": "规则名称",
  "description": "规则描述",
  "enabled": true,
  "priority": 10,
  "category": "personal_info",
  "sensitivity": "medium",
  "condition": {
    "type": "regex",
    "pattern": "正则表达式"
  },
  "action": {
    "algorithm": "mask",
    "params": {
      "maskChar": "*",
      "prefix": 3,
      "suffix": 4
    }
  },
  "metadata": {
    "author": "创建者"
  }
}
```

**响应示例:**
```json
{
  "success": true,
  "data": {
    "id": "rule_1753160994740",
    "name": "规则名称",
    ...
  },
  "message": "Rule created successfully",
  "timestamp": 1753160994742
}
```

#### PUT /api/rules/:id

更新规则

**路径参数:**
- `id`: 规则ID

**请求体:** 与创建规则相同

**响应示例:**
```json
{
  "success": true,
  "data": {
    "id": "rule_001",
    "name": "更新后的规则名称",
    ...
  },
  "message": "Rule updated successfully",
  "timestamp": 1753160994742
}
```

#### DELETE /api/rules/:id

删除规则

**路径参数:**
- `id`: 规则ID

**响应示例:**
```json
{
  "success": true,
  "message": "Rule deleted successfully",
  "timestamp": 1753160994742
}
```

### 批量操作

#### POST /api/rules/batch

批量操作规则

**请求体:**
```json
{
  "operation": "enable|disable|delete",
  "ruleIds": ["rule_001", "rule_002"]
}
```

**响应示例:**
```json
{
  "success": true,
  "successCount": 2,
  "failureCount": 0,
  "message": "Batch operation completed: 2 successful, 0 failed",
  "timestamp": 1753160994742
}
```

### 统计信息

#### GET /api/metrics

获取服务统计指标

**响应示例:**
```json
{
  "totalRules": 3,
  "enabledRules": 3,
  "disabledRules": 0,
  "rulesByType": {
    "regex": 2,
    "key_keyword": 1,
    "jsonpath": 0,
    "combined": 0
  },
  "rulesBySeverity": {
    "critical": 0,
    "high": 1,
    "medium": 2,
    "low": 0
  },
  "lastUpdated": 1753160985807
}
```

## 数据模型

### 规则对象 (Rule)

```typescript
interface Rule {
  id: string;
  name: string;
  description: string;
  enabled: boolean;
  priority: number;
  category: "personal_info" | "financial" | "security" | "medical" | "business" | "other";
  sensitivity: "low" | "medium" | "high" | "critical";
  condition: RuleCondition;
  action: RuleAction;
  metadata: {
    createdAt: string;
    updatedAt: string;
    version: string;
    author: string;
  };
}
```

### 条件类型 (RuleCondition)

#### 正则表达式条件
```typescript
{
  type: "regex";
  pattern: string;
  description?: string;
}
```

#### 关键字条件
```typescript
{
  type: "key_keyword";
  keywords: string[];
  description?: string;
}
```

#### JSON路径条件
```typescript
{
  type: "jsonpath";
  path: string;
  description?: string;
}
```

#### 组合条件
```typescript
{
  type: "combined";
  operator: "OR" | "AND";
  conditions: RuleCondition[];
}
```

### 动作类型 (RuleAction)

#### 掩码动作
```typescript
{
  algorithm: "mask";
  params: {
    maskChar: string;
    prefix: number;
    suffix: number;
    keepDomain?: boolean;
  };
}
```

#### 哈希动作
```typescript
{
  algorithm: "hash";
  params: {
    type: "sha256" | "md5" | "sha1";
    salt: string;
  };
}
```

#### 加密动作
```typescript
{
  algorithm: "encrypt";
  params: {
    key: string;
    iv?: string;
  };
}
```

#### 替换动作
```typescript
{
  algorithm: "replace";
  params: {
    replacement: string;
  };
}
```

#### 移除动作
```typescript
{
  algorithm: "remove";
  params: {};
}
```

## 错误响应

所有API在发生错误时返回以下格式：

```json
{
  "success": false,
  "error": "错误描述",
  "timestamp": 1753160994742
}
```

### 常见HTTP状态码

- `200 OK`: 请求成功
- `201 Created`: 资源创建成功
- `400 Bad Request`: 请求参数错误
- `404 Not Found`: 资源不存在
- `500 Internal Server Error`: 服务器内部错误

## 使用示例

### 获取所有启用的规则
```bash
curl -s "http://localhost:3001/api/rules?enabled=true"
```

### 创建新规则
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "name": "银行卡号脱敏",
    "description": "对银行卡号进行脱敏处理",
    "enabled": true,
    "priority": 15,
    "category": "financial",
    "sensitivity": "high",
    "condition": {
      "type": "regex",
      "pattern": "^[0-9]{16,19}$"
    },
    "action": {
      "algorithm": "mask",
      "params": {
        "maskChar": "*",
        "prefix": 4,
        "suffix": 4
      }
    },
    "metadata": {
      "author": "admin"
    }
  }' \
  http://localhost:3001/api/rules
```

### 批量禁用规则
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "operation": "disable",
    "ruleIds": ["rule_001", "rule_002"]
  }' \
  http://localhost:3001/api/rules/batch
```

## 数据持久化

- 规则数据存储在 `data/rules.json` 文件中
- 配置数据存储在 `data/config.json` 文件中
- 支持Docker卷挂载进行数据持久化

## 监控和日志

- 健康检查端点: `/api/health`
- 服务指标: `/api/metrics`
- 日志输出到控制台（可配置文件输出）
- 支持Docker日志收集

## 扩展功能

### 计划中的功能
- [ ] 规则验证API
- [ ] 配置版本管理
- [ ] 审计日志
- [ ] 权限认证
- [ ] 规则测试工具

### 集成说明

该API服务可以被其他系统调用来获取脱敏配置：

1. **Java应用集成**: 可在应用启动时调用 `/api/config` 获取规则配置
2. **实时更新**: 可定期轮询 `/api/rules` 检查规则更新
3. **监控集成**: 可通过 `/api/health` 和 `/api/metrics` 进行服务监控
