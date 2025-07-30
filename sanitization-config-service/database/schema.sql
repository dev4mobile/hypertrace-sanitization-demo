-- 脱敏配置服务数据库表结构
-- PostgreSQL Schema for Sanitization Config Service

-- 创建扩展
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 脱敏规则表
CREATE TABLE IF NOT EXISTS sanitization_rules (
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

-- 全局配置表
CREATE TABLE IF NOT EXISTS sanitization_config (
    id SERIAL PRIMARY KEY,
    config_key VARCHAR(255) UNIQUE NOT NULL,
    config_value JSONB NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 规则历史表 (用于审计和版本控制)
CREATE TABLE IF NOT EXISTS sanitization_rules_history (
    id SERIAL PRIMARY KEY,
    rule_id VARCHAR(255) NOT NULL,
    operation VARCHAR(20) NOT NULL, -- 'CREATE', 'UPDATE', 'DELETE'
    old_data JSONB,
    new_data JSONB,
    changed_by VARCHAR(255),
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    change_reason TEXT
);

-- 创建索引以提高查询性能
CREATE INDEX IF NOT EXISTS idx_sanitization_rules_enabled ON sanitization_rules(enabled);
CREATE INDEX IF NOT EXISTS idx_sanitization_rules_category ON sanitization_rules(category);
CREATE INDEX IF NOT EXISTS idx_sanitization_rules_priority ON sanitization_rules(priority);
CREATE INDEX IF NOT EXISTS idx_sanitization_rules_severity ON sanitization_rules(severity);
CREATE INDEX IF NOT EXISTS idx_sanitization_rules_sensitivity ON sanitization_rules(sensitivity);
CREATE INDEX IF NOT EXISTS idx_sanitization_rules_created_at ON sanitization_rules(created_at);
CREATE INDEX IF NOT EXISTS idx_sanitization_rules_updated_at ON sanitization_rules(updated_at);

-- 条件字段的 GIN 索引用于 JSON 查询
CREATE INDEX IF NOT EXISTS idx_sanitization_rules_condition ON sanitization_rules USING GIN(condition);
CREATE INDEX IF NOT EXISTS idx_sanitization_rules_action ON sanitization_rules USING GIN(action);
CREATE INDEX IF NOT EXISTS idx_sanitization_rules_metadata ON sanitization_rules USING GIN(metadata);

-- 配置表索引
CREATE INDEX IF NOT EXISTS idx_sanitization_config_key ON sanitization_config(config_key);

-- 历史表索引
CREATE INDEX IF NOT EXISTS idx_sanitization_rules_history_rule_id ON sanitization_rules_history(rule_id);
CREATE INDEX IF NOT EXISTS idx_sanitization_rules_history_operation ON sanitization_rules_history(operation);
CREATE INDEX IF NOT EXISTS idx_sanitization_rules_history_changed_at ON sanitization_rules_history(changed_at);

-- 创建更新时间戳的触发器函数
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 为规则表创建更新时间戳触发器
CREATE TRIGGER update_sanitization_rules_updated_at
    BEFORE UPDATE ON sanitization_rules
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 为配置表创建更新时间戳触发器
CREATE TRIGGER update_sanitization_config_updated_at
    BEFORE UPDATE ON sanitization_config
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 创建规则历史记录触发器函数
CREATE OR REPLACE FUNCTION log_rule_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        INSERT INTO sanitization_rules_history(rule_id, operation, old_data, changed_at)
        VALUES(OLD.id, 'DELETE', row_to_json(OLD), CURRENT_TIMESTAMP);
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO sanitization_rules_history(rule_id, operation, old_data, new_data, changed_at)
        VALUES(NEW.id, 'UPDATE', row_to_json(OLD), row_to_json(NEW), CURRENT_TIMESTAMP);
        RETURN NEW;
    ELSIF TG_OP = 'INSERT' THEN
        INSERT INTO sanitization_rules_history(rule_id, operation, new_data, changed_at)
        VALUES(NEW.id, 'CREATE', row_to_json(NEW), CURRENT_TIMESTAMP);
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ language 'plpgsql';

-- 为规则表创建历史记录触发器
CREATE TRIGGER sanitization_rules_history_trigger
    AFTER INSERT OR UPDATE OR DELETE ON sanitization_rules
    FOR EACH ROW EXECUTE FUNCTION log_rule_changes();

-- 插入默认配置
INSERT INTO sanitization_config (config_key, config_value, description)
VALUES
    ('global_enabled', '{"enabled": true}', '全局脱敏开关'),
    ('global_settings', '{"version": "1.0.0", "markersEnabled": false, "markerFormat": "[MASKED]", "saltValue": "hypertrace_default_salt_2024", "encryptionKey": "hypertrace_encryption_key_2024"}', '全局设置'),
    ('salt_config', '{"saltValue": "hypertrace_default_salt_2024", "autoGenerate": false, "rotationEnabled": false}', 'Salt值配置'),
    ('encryption_config', '{"algorithm": "AES-256-GCM", "keyRotationDays": 90, "encryptionKey": "hypertrace_encryption_key_2024"}', '加密配置')
ON CONFLICT (config_key) DO NOTHING;

-- 插入默认脱敏规则
INSERT INTO sanitization_rules (
    id, name, description, enabled, priority, category,
    sensitivity, condition, action,
    created_at, updated_at, created_by, version
) VALUES
    ('default-phone-rule', '手机号脱敏', '通过字段名称匹配手机号字段并进行脱敏处理', true, 10, 'personal_info',
     'high',
     '{"type": "key_keyword", "keywords": ["phone", "mobile", "phoneNumber", "tel", "cellphone"], "caseSensitive": false}',
     '{"algorithm": "mask", "params": {"maskChar": "*", "prefix": 3, "suffix": 4, "keepDomain": false}}',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'system', '1.0'),
         ('default-email-rule', '邮箱脱敏', '通过字段名称匹配邮箱字段并进行脱敏处理，保留域名部分', true, 20, 'personal_info',
      'medium',
      '{"type": "key_keyword", "keywords": ["email", "emailAddress", "mail", "userEmail", "e_mail", "Email", "EMAIL"], "caseSensitive": false}',
      '{"algorithm": "mask", "params": {"maskChar": "*", "prefix": 3, "suffix": 0, "keepDomain": true}}',
      CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'system', '1.0'),
    ('default-idcard-rule', '身份证脱敏', '通过字段名称匹配身份证字段并进行脱敏处理', true, 5, 'personal_info',
     'critical',
     '{"type": "key_keyword", "keywords": ["idCard", "identityCard", "citizenId", "idNumber"], "caseSensitive": false}',
     '{"algorithm": "mask", "params": {"maskChar": "*", "prefix": 4, "suffix": 4, "keepDomain": false}}',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'system', '1.0'),
    ('default-credit-card-rule', '信用卡脱敏', '通过字段名称匹配信用卡字段并进行脱敏处理', true, 5, 'financial',
     'critical',
     '{"type": "key_keyword", "keywords": ["cardNumber", "creditCard", "bankCard", "cardNo"], "caseSensitive": false}',
     '{"algorithm": "mask", "params": {"maskChar": "*", "prefix": 4, "suffix": 4, "keepDomain": false}}',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'system', '1.0')
ON CONFLICT (id) DO NOTHING;

-- 注释
COMMENT ON TABLE sanitization_rules IS '脱敏规则表';
COMMENT ON TABLE sanitization_config IS '脱敏配置表';
COMMENT ON TABLE sanitization_rules_history IS '脱敏规则变更历史表';

COMMENT ON COLUMN sanitization_rules.condition IS 'JSON格式的规则条件配置，支持regex、key_keyword、jsonpath、combined等类型';
COMMENT ON COLUMN sanitization_rules.action IS 'JSON格式的脱敏动作配置，支持mask、hash、encrypt、replace、remove等算法';
COMMENT ON COLUMN sanitization_rules.metadata IS 'JSON格式的元数据，包含创建者、版本等信息';
