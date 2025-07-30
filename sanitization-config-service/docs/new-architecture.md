# 脱敏配置服务 - 新架构说明

## 概述

本文档描述了脱敏配置服务在清理旧格式字段后的新架构。我们已经移除了所有旧的混合格式字段，统一使用新的条件-动作（Condition-Action）模式。

## 数据库架构

### sanitization_rules 表结构

```sql
CREATE TABLE sanitization_rules (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    enabled BOOLEAN DEFAULT true,
    priority INTEGER DEFAULT 0,
    category VARCHAR(50),

    -- 敏感度级别
    sensitivity VARCHAR(20), -- 'low', 'medium', 'high', 'critical'

    -- 条件配置 (JSON格式存储，支持复杂条件)
    condition JSONB NOT NULL,

    -- 动作配置 (JSON格式存储)
    action JSONB NOT NULL,

    -- 应用条件
    include_services TEXT[],
    exclude_services TEXT[],
    conditions JSONB,

    -- 元数据
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(255) DEFAULT 'system',
    version VARCHAR(20) DEFAULT '1.0'
);
```

## 条件类型 (Condition Types)

### 1. key_keyword - 字段名关键词匹配

用于根据字段名中的关键词来识别需要脱敏的字段。

```json
{
  "type": "key_keyword",
  "keywords": ["email", "emailAddress", "mail", "userEmail"],
  "caseSensitive": false
}
```

**参数说明：**
- `keywords`: 要匹配的关键词数组
- `caseSensitive`: 是否区分大小写（可选，默认false）

### 2. regex - 正则表达式匹配

用于根据字段值的模式来识别需要脱敏的数据。

```json
{
  "type": "regex",
  "pattern": "^\\d{11}$"
}
```

**参数说明：**
- `pattern`: 正则表达式模式



## 动作类型 (Action Types)

### 1. mask - 掩码脱敏

保留部分字符，其余用指定字符替换。

```json
{
  "algorithm": "mask",
  "params": {
    "maskChar": "*",
    "prefix": 3,
    "suffix": 4,
    "keepDomain": true
  }
}
```

**参数说明：**
- `maskChar`: 掩码字符（默认 "*"）
- `prefix`: 保留前几位字符
- `suffix`: 保留后几位字符
- `keepDomain`: 对于邮箱，是否保留域名部分

### 2. hash - 哈希脱敏

使用哈希算法对数据进行不可逆脱敏。

```json
{
  "algorithm": "hash",
  "params": {
    "hashAlgorithm": "SHA-256",
    "saltValue": "custom_salt"
  }
}
```

### 3. encrypt - 加密脱敏

使用加密算法对数据进行可逆脱敏。

```json
{
  "algorithm": "encrypt",
  "params": {
    "algorithm": "AES-256-GCM",
    "key": "encryption_key"
  }
}
```

### 4. replace - 替换脱敏

用固定值替换原数据。

```json
{
  "algorithm": "replace",
  "params": {
    "replacement": "[MASKED]"
  }
}
```

### 5. remove - 移除脱敏

完全移除敏感数据。

```json
{
  "algorithm": "remove",
  "params": {}
}
```

## 默认规则示例

### 邮箱脱敏规则

```json
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
    "keywords": ["email", "emailAddress", "mail", "userEmail", "e_mail", "Email", "EMAIL"],
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
  }
}
```

### 手机号脱敏规则

```json
{
  "id": "default-phone-rule",
  "name": "手机号脱敏",
  "description": "通过字段名称匹配手机号字段并进行脱敏处理",
  "enabled": true,
  "priority": 10,
  "category": "personal_info",
  "sensitivity": "high",
  "condition": {
    "type": "key_keyword",
    "keywords": ["phone", "mobile", "phoneNumber", "tel", "cellphone"],
    "caseSensitive": false
  },
  "action": {
    "algorithm": "mask",
    "params": {
      "maskChar": "*",
      "prefix": 3,
      "suffix": 4,
      "keepDomain": false
    }
  }
}
```

## API 接口

### 获取规则

```bash
GET /api/sanitization/rules
```

**查询参数：**
- `enabled`: 过滤启用/禁用状态
- `category`: 按类别过滤
- `severity`: 按敏感度过滤
- `limit`: 分页限制
- `offset`: 分页偏移

### 创建规则

```bash
POST /api/sanitization/rules
Content-Type: application/json

{
  "name": "自定义规则",
  "description": "规则描述",
  "category": "personal_info",
  "sensitivity": "high",
  "condition": { ... },
  "action": { ... }
}
```

## 迁移说明

### 已移除的字段

以下旧格式字段已被完全移除：

- `rule_type` → 使用 `condition.type`
- `severity` → 使用 `sensitivity`
- `field_names` → 使用 `condition.keywords`
- `pattern` → 使用 `condition.pattern`
- `mask_value` → 使用 `action.params.replacement`
- `marker_type` → 不再支持
- `preserve_format` → 不再支持
- `preserve_length` → 不再支持
- `content_types` → 不再支持

### 类型映射

旧类型 → 新类型：
- `FIELD_NAME` → `key_keyword`
- `PATTERN` → `regex`

敏感度级别：
- `LOW` → `low`
- `MEDIUM` → `medium`
- `HIGH` → `high`
- `CRITICAL` → `critical`

## 性能优化

1. **索引优化**：为 `condition` 和 `action` 字段创建了GIN索引
2. **查询优化**：移除了旧字段的复杂查询逻辑
3. **数据一致性**：统一使用JSON格式存储配置

## 兼容性说明

- **完全移除旧格式**：不再支持旧的混合格式字段
- **API变更**：移除了 `type` 查询参数
- **前端更新**：更新了所有类型显示和验证逻辑
- **数据库迁移**：需要运行迁移脚本更新现有数据

## 最佳实践

1. **条件设计**：优先使用 `key_keyword` 进行字段名匹配
2. **动作选择**：根据数据敏感度选择合适的脱敏算法
3. **性能考虑**：避免使用过于复杂的正则表达式
4. **测试验证**：新规则上线前充分测试匹配效果
