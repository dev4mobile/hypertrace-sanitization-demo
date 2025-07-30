const { Client } = require('pg');
require('dotenv').config();

// 数据库连接配置
const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'sanitization_config',
  user: process.env.DB_USER || 'sanitization_user',
  password: process.env.DB_PASSWORD || 'sanitization_pass_2024!',
  ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false
};

const client = new Client(dbConfig);

async function initializeDatabase() {
  try {
    console.log('🔗 Connecting to database...');
    await client.connect();
    console.log('✅ Connected to database');

    console.log('🔧 Checking if tables exist...');

    // 检查表是否存在
    const tableCheckQuery = `
      SELECT EXISTS (
        SELECT FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name = 'sanitization_rules'
      );
    `;

    const tableExists = await client.query(tableCheckQuery);

    if (!tableExists.rows[0].exists) {
      console.log('📝 Creating database schema...');

      // 读取并执行schema.sql
      const fs = require('fs');
      const path = require('path');
      const schemaPath = path.join(__dirname, '../../database/schema.sql');
      const schema = fs.readFileSync(schemaPath, 'utf8');

      await client.query(schema);
      console.log('✅ Database schema created successfully');
    } else {
      console.log('✅ Database tables already exist');
    }

    // 检查并更新配置
    console.log('🔧 Checking and updating configurations...');

    const configsToCheck = [
      {
        key: 'global_enabled',
        value: { enabled: true },
        description: '全局脱敏开关'
      },
      {
        key: 'global_settings',
        value: {
          version: "1.0.0",
          markersEnabled: false,
          markerFormat: "[MASKED]",
          saltValue: "hypertrace_default_salt_2024",
          encryptionKey: "hypertrace_encryption_key_2024"
        },
        description: '全局设置'
      },
      {
        key: 'salt_config',
        value: {
          saltValue: "hypertrace_default_salt_2024",
          autoGenerate: false,
          rotationEnabled: false
        },
        description: 'Salt值配置'
      },
      {
        key: 'encryption_config',
        value: {
          algorithm: "AES-256-GCM",
          keyRotationDays: 90,
          encryptionKey: "hypertrace_encryption_key_2024"
        },
        description: '加密配置'
      }
    ];

    for (const config of configsToCheck) {
      const checkQuery = 'SELECT * FROM sanitization_config WHERE config_key = $1';
      const result = await client.query(checkQuery, [config.key]);

      if (result.rows.length === 0) {
        const insertQuery = `
          INSERT INTO sanitization_config (config_key, config_value, description)
          VALUES ($1, $2, $3)
        `;
        await client.query(insertQuery, [config.key, JSON.stringify(config.value), config.description]);
        console.log(`✅ Added configuration: ${config.key}`);
      } else {
        console.log(`ℹ️  Configuration already exists: ${config.key}`);
      }
    }

    // 检查并插入默认规则
    console.log('🔧 Checking and updating default rules...');

    const defaultRules = [
      {
        id: 'default-phone-rule',
        name: '手机号脱敏',
        description: '通过字段名称匹配手机号字段并进行脱敏处理',
        enabled: true,
        priority: 10,
        category: 'personal_info',
        sensitivity: 'high',
        condition: {
          type: 'key_keyword',
          keywords: ['phone', 'mobile', 'phoneNumber', 'tel', 'cellphone'],
          caseSensitive: false
        },
        action: {
          algorithm: 'mask',
          params: {
            maskChar: '*',
            prefix: 3,
            suffix: 4,
            keepDomain: false
          }
        }
      },
      {
        id: 'default-email-rule',
        name: '邮箱脱敏',
        description: '通过字段名称匹配邮箱字段并进行脱敏处理，保留域名部分',
        enabled: true,
        priority: 20,
        category: 'personal_info',
        sensitivity: 'medium',
        condition: {
          type: 'key_keyword',
          keywords: ['email', 'emailAddress', 'mail', 'userEmail', 'e_mail', 'Email', 'EMAIL'],
          caseSensitive: false
        },
        action: {
          algorithm: 'mask',
          params: {
            maskChar: '*',
            prefix: 3,
            suffix: 0,
            keepDomain: true
          }
        }
      },
      {
        id: 'default-idcard-rule',
        name: '身份证脱敏',
        description: '通过字段名称匹配身份证字段并进行脱敏处理',
        enabled: true,
        priority: 5,
        category: 'personal_info',
        sensitivity: 'critical',
        condition: {
          type: 'key_keyword',
          keywords: ['idCard', 'identityCard', 'citizenId', 'idNumber'],
          caseSensitive: false
        },
        action: {
          algorithm: 'mask',
          params: {
            maskChar: '*',
            prefix: 4,
            suffix: 4,
            keepDomain: false
          }
        }
      },
      {
        id: 'default-credit-card-rule',
        name: '信用卡脱敏',
        description: '通过字段名称匹配信用卡字段并进行脱敏处理',
        enabled: true,
        priority: 5,
        category: 'financial',
        sensitivity: 'critical',
        condition: {
          type: 'key_keyword',
          keywords: ['cardNumber', 'creditCard', 'bankCard', 'cardNo'],
          caseSensitive: false
        },
        action: {
          algorithm: 'mask',
          params: {
            maskChar: '*',
            prefix: 4,
            suffix: 4,
            keepDomain: false
          }
        }
      }
    ];

    for (const rule of defaultRules) {
      const checkQuery = 'SELECT * FROM sanitization_rules WHERE id = $1';
      const result = await client.query(checkQuery, [rule.id]);

      if (result.rows.length === 0) {
        const insertQuery = `
          INSERT INTO sanitization_rules (
            id, name, description, enabled, priority, category,
            sensitivity, condition, action,
            created_at, updated_at, created_by, version
          ) VALUES (
            $1, $2, $3, $4, $5, $6, $7, $8, $9,
            CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'system', '1.0'
          )
        `;
        await client.query(insertQuery, [
          rule.id, rule.name, rule.description, rule.enabled,
          rule.priority, rule.category, rule.sensitivity,
          JSON.stringify(rule.condition), JSON.stringify(rule.action)
        ]);
        console.log(`✅ Added default rule: ${rule.name}`);
      } else {
        console.log(`ℹ️  Default rule already exists: ${rule.name}`);
      }
    }

    console.log('🎉 Database initialization completed successfully!');

    // 显示统计信息
    const statsQuery = `
      SELECT
        (SELECT COUNT(*) FROM sanitization_rules) as total_rules,
        (SELECT COUNT(*) FROM sanitization_rules WHERE enabled = true) as enabled_rules,
        (SELECT COUNT(*) FROM sanitization_config) as total_configs
    `;
    const stats = await client.query(statsQuery);
    const { total_rules, enabled_rules, total_configs } = stats.rows[0];

    console.log('\n📊 Database Statistics:');
    console.log(`   Total Rules: ${total_rules}`);
    console.log(`   Enabled Rules: ${enabled_rules}`);
    console.log(`   Total Configurations: ${total_configs}`);

  } catch (error) {
    console.error('❌ Database initialization failed:', error);
    process.exit(1);
  } finally {
    await client.end();
    console.log('🔌 Database connection closed');
  }
}

// 用于服务器集成的初始化函数（使用现有连接）
async function initializeForServer() {
  const db = require('../database/connection');

  try {
    console.log('🔧 Initializing database data...');

    // 检查是否已有数据
    const rulesCount = await db.query('SELECT COUNT(*) as count FROM sanitization_rules');
    if (parseInt(rulesCount.rows[0].count) > 0) {
      console.log('✅ Database already has rules, skipping initialization');
      return;
    }

    // 插入默认配置
    console.log('📝 Inserting default configurations...');
    await db.query(`
      INSERT INTO sanitization_config (config_key, config_value, description)
      VALUES
        ('global_enabled', '{"enabled": true}', '全局脱敏开关'),
        ('global_settings', '{"version": "1.0.0", "markersEnabled": false, "markerFormat": "[MASKED]", "saltValue": "hypertrace_default_salt_2024", "encryptionKey": "hypertrace_encryption_key_2024"}', '全局设置'),
        ('salt_config', '{"saltValue": "hypertrace_default_salt_2024", "autoGenerate": false, "rotationEnabled": false}', 'Salt值配置'),
        ('encryption_config', '{"algorithm": "AES-256-GCM", "keyRotationDays": 90, "encryptionKey": "hypertrace_encryption_key_2024"}', '加密配置')
      ON CONFLICT (config_key) DO NOTHING
    `);

    // 插入默认规则
    console.log('📋 Inserting default sanitization rules...');
    await db.query(`
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
      ON CONFLICT (id) DO NOTHING
    `);

    // 统计信息
    const stats = await db.query(`
      SELECT
        (SELECT COUNT(*) FROM sanitization_rules) as total_rules,
        (SELECT COUNT(*) FROM sanitization_rules WHERE enabled = true) as enabled_rules,
        (SELECT COUNT(*) FROM sanitization_config) as total_configs
    `);

    const { total_rules, enabled_rules, total_configs } = stats.rows[0];
    console.log('📊 Database initialization completed:');
    console.log(`   Total Rules: ${total_rules}`);
    console.log(`   Enabled Rules: ${enabled_rules}`);
    console.log(`   Total Configurations: ${total_configs}`);

  } catch (error) {
    console.error('❌ Database data initialization failed:', error);
    throw error;
  }
}

// 运行初始化
if (require.main === module) {
  initializeDatabase();
}

module.exports = {
  initializeDatabase,
  initializeForServer
};
