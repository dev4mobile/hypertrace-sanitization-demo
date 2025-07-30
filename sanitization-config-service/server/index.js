const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');
const db = require('./database/connection');
const sanitizationDAO = require('./database/sanitization-dao');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3001;

// 中间件配置
app.use(helmet());
app.use(compression());
app.use(cors({
  origin: process.env.FRONTEND_URL || ['http://localhost:3000', 'http://localhost:3001'],
  credentials: true
}));
app.use(morgan('combined'));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// 数据库连接状态
let databaseReady = false;

// 初始化数据库连接
async function initializeDatabase() {
  try {
    await db.initialize();
    databaseReady = true;
    console.log('✅ Database connection established');
  } catch (error) {
    console.error('❌ Failed to connect to database:', error);
    databaseReady = false;
    // 在生产环境中，可能需要退出进程
    if (process.env.NODE_ENV === 'production') {
      process.exit(1);
    }
  }
}

// 数据库状态检查中间件
const requireDatabase = (req, res, next) => {
  if (!databaseReady) {
    return res.status(503).json({
      success: false,
      error: 'Database connection not available',
      timestamp: Date.now()
    });
  }
  next();
};

// API路由

// 获取脱敏规则（标准化接口）
app.get('/api/sanitization/rules', requireDatabase, async (req, res) => {
  try {
    const { enabled, category, severity, type, limit, offset } = req.query;

    const filters = {};
    if (enabled !== undefined) {
      filters.enabled = enabled === 'true';
    }
    if (category) {
      filters.category = category;
    }
    if (severity) {
      filters.severity = severity;
    }
    // Note: type filter is no longer supported as we removed rule_type field

    const rules = await sanitizationDAO.getAllRules(filters);

    // 分页处理
    let paginatedRules = rules;
    const totalCount = rules.length;

    if (offset !== undefined || limit !== undefined) {
      const startIndex = parseInt(offset) || 0;
      const limitNum = parseInt(limit) || totalCount;
      paginatedRules = rules.slice(startIndex, startIndex + limitNum);
    }

    // 格式化规则数据，确保符合 rules.json 的新格式
    const formattedRules = paginatedRules.map(rule => {
      // 如果规则有新格式的 condition 和 action，直接使用
      if (rule.condition && rule.action) {
        return {
          id: rule.id,
          name: rule.name,
          description: rule.description,
          enabled: rule.enabled,
          priority: rule.priority,
          category: rule.category,
          sensitivity: rule.sensitivity,
          condition: rule.condition,
          action: rule.action,
          metadata: rule.metadata || {
            createdAt: rule.createdAt,
            updatedAt: rule.updatedAt,
            version: rule.version || "1.0",
            author: rule.createdBy || "system"
          }
        };
      }

      // 否则将旧格式转换为新格式
      const convertedRule = {
        id: rule.id,
        name: rule.name,
        description: rule.description,
        enabled: rule.enabled,
        priority: rule.priority,
        category: rule.category,
        sensitivity: rule.severity ? rule.severity.toLowerCase() : "medium",
        condition: null,
        action: null,
        metadata: {
          createdAt: rule.createdAt,
          updatedAt: rule.updatedAt,
          version: rule.version || "1.0",
          author: rule.createdBy || "system"
        }
      };

      // 转换条件格式
      if (rule.pattern) {
        convertedRule.condition = {
          type: "regex",
          pattern: rule.pattern
        };
      } else if (rule.fieldNames && rule.fieldNames.length > 0) {
        convertedRule.condition = {
          type: "key_keyword",
          keywords: rule.fieldNames
        };
      }

      // 转换动作格式
      convertedRule.action = {
        algorithm: "mask",
        params: {
          maskChar: "*",
          prefix: rule.maskValue && rule.maskValue.includes("***") ? 3 : 2,
          suffix: rule.maskValue && rule.maskValue.includes("****") ? 4 : 0,
          keepDomain: rule.pattern && rule.pattern.includes("@") ? true : undefined
        }
      };

      return convertedRule;
    });

    res.json({
      success: true,
      data: {
        rules: formattedRules,
        pagination: {
          total: totalCount,
          offset: parseInt(offset) || 0,
          limit: parseInt(limit) || totalCount,
          hasMore: (parseInt(offset) || 0) + (parseInt(limit) || totalCount) < totalCount
        }
      },
      timestamp: Date.now()
    });
  } catch (error) {
    console.error('Error getting sanitization rules:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      details: 'Failed to retrieve sanitization rules',
      timestamp: Date.now()
    });
  }
});

// 健康检查
app.get('/api/health', async (req, res) => {
  try {
    let dbHealth = { status: 'unhealthy', error: 'Database not connected' };
    let rulesCount = 0;

    if (databaseReady) {
      dbHealth = await db.checkHealth();

      // 检查规则数量
      try {
        const result = await db.query('SELECT COUNT(*) as count FROM sanitization_rules');
        rulesCount = parseInt(result.rows[0].count);
      } catch (error) {
        console.warn('Failed to get rules count:', error.message);
      }
    }

    const health = {
      status: databaseReady && dbHealth.status === 'healthy' ? 'healthy' : 'unhealthy',
      timestamp: new Date().toISOString(),
      version: '1.0.0',
      uptime: process.uptime(),
      checks: {
        database: dbHealth.status,
        rules: rulesCount > 0 ? 'ready' : 'no_data',
        memory: process.memoryUsage().heapUsed < 100 * 1024 * 1024 ? 'healthy' : 'warning'
      },
      database: dbHealth,
      stats: {
        rulesCount: rulesCount
      }
    };

    const statusCode = health.status === 'healthy' ? 200 : 503;
    res.status(statusCode).json(health);
  } catch (error) {
    res.status(500).json({
      status: 'unhealthy',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// 获取完整配置
app.get('/api/config', requireDatabase, async (req, res) => {
  try {
    const rules = await sanitizationDAO.getAllRules();
    const globalConfig = await sanitizationDAO.getConfig('global_enabled');
    const globalSettings = await sanitizationDAO.getConfig('global_settings');

    const config = {
      enabled: globalConfig ? globalConfig.value.enabled : true,
      version: "1.0.0",
      timestamp: Date.now(),
      rules: rules,
      globalSettings: globalSettings ? globalSettings.value : {
        version: "1.0.0",
        markersEnabled: false,
        markerFormat: "[MASKED]"
      }
    };

    res.json({
      success: true,
      data: config,
      timestamp: Date.now()
    });
  } catch (error) {
    console.error('Error getting config:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      timestamp: Date.now()
    });
  }
});

// 获取所有规则
app.get('/api/rules', requireDatabase, async (req, res) => {
  try {
    const { enabled, category, severity } = req.query;

    const filters = {};
    if (enabled !== undefined) {
      filters.enabled = enabled === 'true';
    }
    if (category) {
      filters.category = category;
    }
    if (severity) {
      filters.severity = severity;
    }

    const rules = await sanitizationDAO.getAllRules(filters);

    res.json({
      success: true,
      data: rules,
      total: rules.length,
      timestamp: Date.now()
    });
  } catch (error) {
    console.error('Error getting rules:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      timestamp: Date.now()
    });
  }
});

// 获取特定规则
app.get('/api/rules/:id', requireDatabase, async (req, res) => {
  try {
    const { id } = req.params;
    const rule = await sanitizationDAO.getRuleById(id);

    if (!rule) {
      return res.status(404).json({
        success: false,
        error: 'Rule not found',
        timestamp: Date.now()
      });
    }

    res.json({
      success: true,
      data: rule,
      timestamp: Date.now()
    });
  } catch (error) {
    console.error('Error getting rule by ID:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      timestamp: Date.now()
    });
  }
});

// 创建新规则
app.post('/api/rules', requireDatabase, async (req, res) => {
  try {
    const newRule = await sanitizationDAO.createRule(req.body);

    res.status(201).json({
      success: true,
      data: newRule,
      message: 'Rule created successfully',
      timestamp: Date.now()
    });
  } catch (error) {
    console.error('Error creating rule:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      timestamp: Date.now()
    });
  }
});

// 更新规则
app.put('/api/rules/:id', requireDatabase, async (req, res) => {
  try {
    const { id } = req.params;
    const updatedRule = await sanitizationDAO.updateRule(id, req.body);

    if (!updatedRule) {
      return res.status(404).json({
        success: false,
        error: 'Rule not found',
        timestamp: Date.now()
      });
    }

    res.json({
      success: true,
      data: updatedRule,
      message: 'Rule updated successfully',
      timestamp: Date.now()
    });
  } catch (error) {
    console.error('Error updating rule:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      timestamp: Date.now()
    });
  }
});

// 删除规则
app.delete('/api/rules/:id', requireDatabase, async (req, res) => {
  try {
    const { id } = req.params;
    const deleted = await sanitizationDAO.deleteRule(id);

    if (!deleted) {
      return res.status(404).json({
        success: false,
        error: 'Rule not found',
        timestamp: Date.now()
      });
    }

    res.json({
      success: true,
      message: 'Rule deleted successfully',
      timestamp: Date.now()
    });
  } catch (error) {
    console.error('Error deleting rule:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      timestamp: Date.now()
    });
  }
});

// 批量操作
app.post('/api/rules/batch', requireDatabase, async (req, res) => {
  try {
    const { operation, ruleIds } = req.body;

    if (!Array.isArray(ruleIds) || ruleIds.length === 0) {
      return res.status(400).json({
        success: false,
        error: 'Invalid ruleIds array',
        timestamp: Date.now()
      });
    }

    if (!['enable', 'disable', 'delete'].includes(operation)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid operation. Must be enable, disable, or delete',
        timestamp: Date.now()
      });
    }

    const result = await sanitizationDAO.batchOperation(ruleIds, operation);

    res.json({
      success: result.success,
      successCount: result.successCount,
      failureCount: result.failureCount,
      failedRules: result.failedRules,
      message: `Batch ${operation} completed: ${result.successCount} successful, ${result.failureCount} failed`,
      timestamp: Date.now()
    });
  } catch (error) {
    console.error('Error in batch operation:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      timestamp: Date.now()
    });
  }
});

// 获取统计信息
app.get('/api/metrics', requireDatabase, async (req, res) => {
  try {
    const metrics = await sanitizationDAO.getMetrics();
    metrics.lastUpdated = Date.now();

    res.json(metrics);
  } catch (error) {
    console.error('Error getting metrics:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      timestamp: Date.now()
    });
  }
});

// 全局配置管理

// 获取全局配置
app.get('/api/config/global', requireDatabase, async (req, res) => {
  try {
    const configs = await sanitizationDAO.getAllConfigs();
    res.json({
      success: true,
      data: configs,
      timestamp: Date.now()
    });
  } catch (error) {
    console.error('Error getting global config:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      timestamp: Date.now()
    });
  }
});

// 更新全局配置
app.post('/api/config/global', requireDatabase, async (req, res) => {
  try {
    const { key, value, description } = req.body;

    if (!key || value === undefined) {
      return res.status(400).json({
        success: false,
        error: 'Key and value are required',
        timestamp: Date.now()
      });
    }

    const config = await sanitizationDAO.setConfig(key, value, description);

    res.json({
      success: true,
      data: config,
      message: 'Configuration updated successfully',
      timestamp: Date.now()
    });
  } catch (error) {
    console.error('Error updating global config:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      timestamp: Date.now()
    });
  }
});

// 更新全局开关状态
app.post('/api/config/global-switch', requireDatabase, async (req, res) => {
  try {
    const { enabled } = req.body;

    if (typeof enabled !== 'boolean') {
      return res.status(400).json({
        success: false,
        error: 'Enabled field must be a boolean',
        timestamp: Date.now()
      });
    }

    const config = await sanitizationDAO.setConfig('global_enabled', { enabled }, '全局脱敏开关');

    res.json({
      success: true,
      data: { enabled, timestamp: Date.now() },
      message: `Global sanitization ${enabled ? 'enabled' : 'disabled'} successfully`,
      timestamp: Date.now()
    });
  } catch (error) {
    console.error('Error updating global switch:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      timestamp: Date.now()
    });
  }
});

// 重置配置到默认值
app.post('/api/config/reset', requireDatabase, async (req, res) => {
  try {
    await db.transaction(async (client) => {
      // 重置配置表
      await client.query('DELETE FROM sanitization_config');
      await client.query(`
        INSERT INTO sanitization_config (config_key, config_value, description)
        VALUES
          ('global_enabled', '{"enabled": true}', '全局脱敏开关'),
          ('global_settings', '{"version": "1.0.0", "markersEnabled": false, "markerFormat": "[MASKED]", "saltValue": "hypertrace_default_salt_2024", "encryptionKey": "hypertrace_encryption_key_2024"}', '全局设置'),
          ('salt_config', '{"saltValue": "hypertrace_default_salt_2024", "autoGenerate": false, "rotationEnabled": false}', 'Salt值配置'),
          ('encryption_config', '{"algorithm": "AES-256-GCM", "keyRotationDays": 90, "encryptionKey": "hypertrace_encryption_key_2024"}', '加密配置')
      `);

      // 重置规则表
      await client.query('DELETE FROM sanitization_rules');
      await client.query(`
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
      `);
    });

    res.json({
      success: true,
      message: 'Configuration reset to defaults successfully',
      timestamp: Date.now()
    });
  } catch (error) {
    console.error('Error resetting configuration:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      timestamp: Date.now()
    });
  }
});

// 数据导入导出

// 导出规则
app.get('/api/export/rules', requireDatabase, async (req, res) => {
  try {
    const rules = await sanitizationDAO.getAllRules();

    res.setHeader('Content-Type', 'application/json');
    res.setHeader('Content-Disposition', `attachment; filename=sanitization-rules-${Date.now()}.json`);
    res.json({
      version: '1.0.0',
      exportDate: new Date().toISOString(),
      totalRules: rules.length,
      rules: rules
    });
  } catch (error) {
    console.error('Error exporting rules:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      timestamp: Date.now()
    });
  }
});

// 提供 /rules.json 端点，返回纯规则数组格式（与 /api/sanitization/rules 保持一致）
app.get('/rules.json', requireDatabase, async (req, res) => {
  try {
    const rules = await sanitizationDAO.getAllRules();

    // 使用与 /api/sanitization/rules 相同的格式化逻辑
    const formattedRules = rules.map(rule => {
      // 如果规则有新格式的 condition 和 action，直接使用
      if (rule.condition && rule.action) {
        return {
          id: rule.id,
          name: rule.name,
          description: rule.description,
          enabled: rule.enabled,
          priority: rule.priority,
          category: rule.category,
          sensitivity: rule.sensitivity,
          condition: rule.condition,
          action: rule.action,
          metadata: rule.metadata || {
            createdAt: rule.createdAt,
            updatedAt: rule.updatedAt,
            version: rule.version || "1.0",
            author: rule.createdBy || "system"
          }
        };
      }

      // 否则将旧格式转换为新格式
      const convertedRule = {
        id: rule.id,
        name: rule.name,
        description: rule.description,
        enabled: rule.enabled,
        priority: rule.priority,
        category: rule.category,
        sensitivity: rule.severity ? rule.severity.toLowerCase() : "medium",
        condition: null,
        action: null,
        metadata: {
          createdAt: rule.createdAt,
          updatedAt: rule.updatedAt,
          version: rule.version || "1.0",
          author: rule.createdBy || "system"
        }
      };

      // 转换条件格式
      if (rule.pattern) {
        convertedRule.condition = {
          type: "regex",
          pattern: rule.pattern
        };
      } else if (rule.fieldNames && rule.fieldNames.length > 0) {
        convertedRule.condition = {
          type: "key_keyword",
          keywords: rule.fieldNames
        };
      }

      // 转换动作格式
      convertedRule.action = {
        algorithm: "mask",
        params: {
          maskChar: "*",
          prefix: rule.maskValue && rule.maskValue.includes("***") ? 3 : 2,
          suffix: rule.maskValue && rule.maskValue.includes("****") ? 4 : 0,
          keepDomain: rule.pattern && rule.pattern.includes("@") ? true : undefined
        }
      };

      return convertedRule;
    });

    res.setHeader('Content-Type', 'application/json');
    res.json(formattedRules);
  } catch (error) {
    console.error('Error getting rules.json:', error);
    // 如果数据库不可用，尝试返回静态文件
    const fs = require('fs');
    const path = require('path');
    const staticRulesPath = path.join(__dirname, '../data/rules.json');

    try {
      if (fs.existsSync(staticRulesPath)) {
        const staticRules = JSON.parse(fs.readFileSync(staticRulesPath, 'utf8'));
        res.json(staticRules);
      } else {
        res.status(500).json({
          success: false,
          error: 'Rules not available',
          timestamp: Date.now()
        });
      }
    } catch (fileError) {
      res.status(500).json({
        success: false,
        error: 'Failed to load rules',
        timestamp: Date.now()
      });
    }
  }
});

// 导入规则
app.post('/api/import/rules', requireDatabase, async (req, res) => {
  try {
    const { rules, replaceExisting = false } = req.body;

    if (!Array.isArray(rules)) {
      return res.status(400).json({
        success: false,
        error: 'Rules must be an array',
        timestamp: Date.now()
      });
    }

    let successCount = 0;
    let failureCount = 0;
    const errors = [];

    // 如果需要替换现有规则，先删除所有规则
    if (replaceExisting) {
      await db.query('DELETE FROM sanitization_rules');
    }

    for (const rule of rules) {
      try {
        await sanitizationDAO.createRule(rule);
        successCount++;
      } catch (error) {
        failureCount++;
        errors.push({
          rule: rule.id || rule.name,
          error: error.message
        });
      }
    }

    res.json({
      success: failureCount === 0,
      successCount,
      failureCount,
      errors: errors.length > 0 ? errors : undefined,
      message: `Import completed: ${successCount} successful, ${failureCount} failed`,
      timestamp: Date.now()
    });
  } catch (error) {
    console.error('Error importing rules:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      timestamp: Date.now()
    });
  }
});

// 错误处理中间件
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({
    success: false,
    error: 'Internal server error',
    timestamp: Date.now()
  });
});

// 404处理
app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: 'Endpoint not found',
    timestamp: Date.now()
  });
});

// 优雅关闭处理
const gracefulShutdown = async (signal) => {
  console.log(`📤 Received ${signal}, shutting down gracefully`);

  try {
    if (databaseReady) {
      await db.close();
      console.log('🔌 Database connection closed');
    }
  } catch (error) {
    console.error('Error during shutdown:', error);
  }

  process.exit(0);
};

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

// 运行数据库初始化
async function initializeDatabaseData() {
  try {
    const initDbScript = require('./scripts/init-db');
    await initDbScript.initializeForServer();
    console.log('✅ Database data initialization completed');
  } catch (error) {
    console.error('❌ Database data initialization failed:', error);
    // 不要因为数据已存在而退出
    if (!error.message.includes('already exists') && !error.message.includes('duplicate key')) {
      throw error;
    }
  }
}

// 启动服务器
async function startServer() {
  try {
    // 初始化数据库连接
    await initializeDatabase();

    // 初始化数据库数据（插入默认规则）
    await initializeDatabaseData();

    // 启动HTTP服务器
    app.listen(PORT, () => {
      console.log('🚀 Sanitization Config Service API started');
      console.log(`📡 Server running on port ${PORT}`);
      console.log(`🗂️  Database: ${databaseReady ? 'Connected' : 'Not Connected'}`);
      console.log(`🔗 Health check: http://localhost:${PORT}/api/health`);
      console.log(`📊 Metrics: http://localhost:${PORT}/api/metrics`);
      console.log(`📋 Rules API: http://localhost:${PORT}/api/sanitization/rules`);
    });

  } catch (error) {
    console.error('❌ Failed to start server:', error);
    process.exit(1);
  }
}

// 启动应用
startServer();
