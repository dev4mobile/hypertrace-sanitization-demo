# 脱敏规则 API 文档

## 获取脱敏规则接口

### 端点
```
GET /api/sanitization/rules
```

### 描述
获取脱敏规则的标准化接口，专门为 Java Agent 中的 `DynamicSensitiveDataSanitizer` 设计。该接口返回格式化的规则数据，支持过滤、分页等功能。

### 请求参数 (Query Parameters)

| 参数名 | 类型 | 必需 | 默认值 | 描述 |
|--------|------|------|--------|------|
| `enabled` | boolean | 否 | - | 过滤启用/禁用的规则 (true/false) |
| `category` | string | 否 | - | 按规则类别过滤 (如: personal_info, financial) |
| `severity` | string | 否 | - | 按严重级别过滤 (LOW/MEDIUM/HIGH/CRITICAL) |
| `type` | string | 否 | - | 已移除：不再支持类型过滤 |
| `limit` | integer | 否 | - | 每页返回的规则数量 |
| `offset` | integer | 否 | 0 | 分页偏移量 |

### 响应格式

#### 成功响应 (200 OK)
```json
{
  "success": true,
  "data": {
    "rules": [
      {
        "id": "default-email-rule",
        "name": "邮箱脱敏",
        "description": "通过字段名称匹配邮箱字段并进行脱敏处理，保留域名部分",
        "enabled": true,
        "priority": 20,
        "category": "personal_info",
        "sensitivity": "medium",
        "condition": {
          "type": "key_keyword",
          "keywords": ["email", "emailAddress", "mail", "userEmail"],
          "caseSensitive": false
        },
        "action": {
          "algorithm": "mask",
          "params": {
            "maskChar": "*",
            "prefix": 3,
            "suffix": 0,
            "keepDomain": true
          }
        },
        "metadata": {
          "createdAt": "2024-01-15T10:30:00.000Z",
          "updatedAt": "2024-01-15T10:30:00.000Z",
          "version": "1.0",
          "author": "system"
        },
        "createdAt": "2024-01-15T10:30:00.000Z",
        "updatedAt": "2024-01-15T10:30:00.000Z"
      }
    ],
    "pagination": {
      "total": 4,
      "offset": 0,
      "limit": 4,
      "hasMore": false
    }
  },
  "timestamp": 1642248600000
}
```

#### 错误响应 (500 Internal Server Error)
```json
{
  "success": false,
  "error": "Database connection failed",
  "details": "Failed to retrieve sanitization rules",
  "timestamp": 1642248600000
}
```

#### 服务不可用 (503 Service Unavailable)
```json
{
  "success": false,
  "error": "Database connection not available",
  "timestamp": 1642248600000
}
```

### 使用示例

#### 1. 获取所有规则
```bash
curl -X GET "http://localhost:3001/api/sanitization/rules"
```

#### 2. 获取启用的规则
```bash
curl -X GET "http://localhost:3001/api/sanitization/rules?enabled=true"
```

#### 3. 按类别和严重级别过滤
```bash
curl -X GET "http://localhost:3001/api/sanitization/rules?category=personal_info&severity=HIGH"
```

#### 4. 分页获取规则
```bash
curl -X GET "http://localhost:3001/api/sanitization/rules?limit=10&offset=0"
```

#### 5. 按敏感度过滤
```bash
curl -X GET "http://localhost:3001/api/sanitization/rules?severity=high"
```

### 规则字段说明

#### 基本字段
- `id`: 规则唯一标识符
- `name`: 规则名称
- `description`: 规则描述
- `enabled`: 是否启用该规则
- `priority`: 规则优先级 (数值越大优先级越高)
- `category`: 规则类别 (如: personal_info, financial, system)

#### 规则定义字段
- `sensitivity`: 敏感度级别 (`low`, `medium`, `high`, `critical`)
- `condition`: JSON 格式的条件配置，支持以下类型：
  - `key_keyword`: 基于字段名关键词匹配
  - `regex`: 基于正则表达式模式匹配
- `action`: JSON 格式的脱敏动作配置，支持以下算法：
  - `mask`: 掩码脱敏（保留部分字符）
  - `hash`: 哈希脱敏
  - `encrypt`: 加密脱敏
  - `replace`: 替换脱敏
  - `remove`: 移除脱敏
- `metadata`: 规则元数据（版本、作者等）

#### 元信息字段
- `version`: 规则版本
- `createdAt`: 创建时间
- `updatedAt`: 更新时间
- `createdBy`: 创建者

### 与 Java Agent 集成

这个接口专门为 Java Agent 中的 `DynamicSensitiveDataSanitizer` 类设计，返回的数据格式与其预期的规则格式完全兼容。

#### 在 Java 中使用
```java
// 在 DynamicSanitizationRuleManager 中调用
String apiUrl = "http://sanitization-service:3001/api/sanitization/rules?enabled=true";
// 获取规则并应用到脱敏器中
```

### 与现有接口的差异

| 接口 | 路径 | 用途 | 返回格式 |
|------|------|------|----------|
| 管理接口 | `/api/rules` | Web 管理界面使用 | 包含完整的管理信息 |
| 简化接口 | `/rules.json` | 简单的规则数组 | 纯数组格式 |
| **标准化接口** | `/api/sanitization/rules` | **Java Agent 使用** | **标准化的 API 响应格式** |

### 性能考虑

- 该接口包含数据库连接检查中间件
- 支持查询过滤以减少数据传输
- 支持分页以处理大量规则
- 响应数据经过格式化以确保兼容性

### 错误处理

接口包含完善的错误处理机制：
- 数据库连接失败时返回 503 状态码
- 查询错误时返回 500 状态码并包含详细错误信息
- 所有响应都包含 timestamp 字段用于调试
