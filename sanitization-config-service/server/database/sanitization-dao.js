const db = require('./connection');
const { v4: uuidv4 } = require('uuid');

class SanitizationDAO {

  // 规则相关操作

  // 获取所有规则
  async getAllRules(filters = {}) {
    try {
      let query = 'SELECT * FROM sanitization_rules';
      const conditions = [];
      const params = [];
      let paramIndex = 1;

      // 添加过滤条件
      if (filters.enabled !== undefined) {
        conditions.push(`enabled = $${paramIndex++}`);
        params.push(filters.enabled);
      }

      if (filters.category) {
        conditions.push(`category = $${paramIndex++}`);
        params.push(filters.category);
      }

      if (filters.severity) {
        conditions.push(`sensitivity = $${paramIndex++}`);
        params.push(filters.severity.toLowerCase());
      }

      if (conditions.length > 0) {
        query += ' WHERE ' + conditions.join(' AND ');
      }

      query += ' ORDER BY priority DESC, created_at DESC';

      const result = await db.query(query, params);
      return result.rows.map(row => this.transformDbRowToRule(row));
    } catch (error) {
      console.error('Error getting all rules:', error);
      throw error;
    }
  }

  // 根据 ID 获取规则
  async getRuleById(ruleId) {
    try {
      const query = 'SELECT * FROM sanitization_rules WHERE id = $1';
      const result = await db.query(query, [ruleId]);

      if (result.rows.length === 0) {
        return null;
      }

      return this.transformDbRowToRule(result.rows[0]);
    } catch (error) {
      console.error('Error getting rule by ID:', error);
      throw error;
    }
  }

  // 创建新规则
  async createRule(ruleData) {
    try {
      const ruleId = ruleData.id || uuidv4();
      const timestamp = new Date().toISOString();

      // 转换规则数据为数据库格式
      const dbData = this.transformRuleToDbFormat(ruleData, ruleId, timestamp);

      const query = `
        INSERT INTO sanitization_rules (
          id, name, description, enabled, priority, category,
          sensitivity, condition, action,
          include_services, exclude_services, conditions,
          metadata, created_at, updated_at, created_by, version
        ) VALUES (
          $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17
        ) RETURNING *
      `;

      const values = [
        dbData.id, dbData.name, dbData.description, dbData.enabled,
        dbData.priority, dbData.category, dbData.sensitivity, dbData.condition, dbData.action,
        dbData.include_services, dbData.exclude_services, dbData.conditions, dbData.metadata,
        dbData.created_at, dbData.updated_at, dbData.created_by, dbData.version
      ];

      const result = await db.query(query, values);
      return this.transformDbRowToRule(result.rows[0]);
    } catch (error) {
      console.error('Error creating rule:', error);
      throw error;
    }
  }

  // 更新规则
  async updateRule(ruleId, ruleData) {
    try {
      const timestamp = new Date().toISOString();
      const dbData = this.transformRuleToDbFormat(ruleData, ruleId, timestamp, true);

      const query = `
        UPDATE sanitization_rules SET
          name = $2, description = $3, enabled = $4, priority = $5,
          category = $6, sensitivity = $7, condition = $8, action = $9,
          include_services = $10, exclude_services = $11, conditions = $12,
          metadata = $13, updated_at = $14, version = $15
        WHERE id = $1
        RETURNING *
      `;

      const values = [
        ruleId, dbData.name, dbData.description, dbData.enabled,
        dbData.priority, dbData.category, dbData.sensitivity, dbData.condition, dbData.action,
        dbData.include_services, dbData.exclude_services, dbData.conditions, dbData.metadata,
        dbData.updated_at, dbData.version
      ];

      const result = await db.query(query, values);

      if (result.rows.length === 0) {
        return null;
      }

      return this.transformDbRowToRule(result.rows[0]);
    } catch (error) {
      console.error('Error updating rule:', error);
      throw error;
    }
  }

  // 删除规则
  async deleteRule(ruleId) {
    try {
      const query = 'DELETE FROM sanitization_rules WHERE id = $1 RETURNING *';
      const result = await db.query(query, [ruleId]);

      return result.rows.length > 0;
    } catch (error) {
      console.error('Error deleting rule:', error);
      throw error;
    }
  }

  // 批量操作
  async batchOperation(ruleIds, operation) {
    try {
      return await db.transaction(async (client) => {
        let successCount = 0;
        let failureCount = 0;
        const failedRules = [];

        for (const ruleId of ruleIds) {
          try {
            let query;
            let params;

            switch (operation) {
              case 'enable':
                query = 'UPDATE sanitization_rules SET enabled = true, updated_at = CURRENT_TIMESTAMP WHERE id = $1';
                params = [ruleId];
                break;
              case 'disable':
                query = 'UPDATE sanitization_rules SET enabled = false, updated_at = CURRENT_TIMESTAMP WHERE id = $1';
                params = [ruleId];
                break;
              case 'delete':
                query = 'DELETE FROM sanitization_rules WHERE id = $1';
                params = [ruleId];
                break;
              default:
                throw new Error(`Unsupported operation: ${operation}`);
            }

            const result = await client.query(query, params);
            if (result.rowCount > 0) {
              successCount++;
            } else {
              failureCount++;
              failedRules.push(ruleId);
            }
          } catch (error) {
            failureCount++;
            failedRules.push(ruleId);
            console.error(`Batch operation failed for rule ${ruleId}:`, error);
          }
        }

        return {
          success: failureCount === 0,
          successCount,
          failureCount,
          failedRules
        };
      });
    } catch (error) {
      console.error('Error in batch operation:', error);
      throw error;
    }
  }

  // 配置相关操作

  // 获取配置
  async getConfig(configKey) {
    try {
      const query = 'SELECT * FROM sanitization_config WHERE config_key = $1';
      const result = await db.query(query, [configKey]);

      if (result.rows.length === 0) {
        return null;
      }

      return {
        key: result.rows[0].config_key,
        value: result.rows[0].config_value,
        description: result.rows[0].description,
        updatedAt: result.rows[0].updated_at
      };
    } catch (error) {
      console.error('Error getting config:', error);
      throw error;
    }
  }

  // 设置配置
  async setConfig(configKey, configValue, description = null) {
    try {
      const query = `
        INSERT INTO sanitization_config (config_key, config_value, description)
        VALUES ($1, $2, $3)
        ON CONFLICT (config_key)
        DO UPDATE SET
          config_value = EXCLUDED.config_value,
          description = COALESCE(EXCLUDED.description, sanitization_config.description),
          updated_at = CURRENT_TIMESTAMP
        RETURNING *
      `;

      const result = await db.query(query, [configKey, JSON.stringify(configValue), description]);
      return {
        key: result.rows[0].config_key,
        value: result.rows[0].config_value,
        description: result.rows[0].description,
        updatedAt: result.rows[0].updated_at
      };
    } catch (error) {
      console.error('Error setting config:', error);
      throw error;
    }
  }

  // 获取所有配置
  async getAllConfigs() {
    try {
      const query = 'SELECT * FROM sanitization_config ORDER BY config_key';
      const result = await db.query(query);

      const configs = {};
      result.rows.forEach(row => {
        configs[row.config_key] = {
          value: row.config_value,
          description: row.description,
          updatedAt: row.updated_at
        };
      });

      return configs;
    } catch (error) {
      console.error('Error getting all configs:', error);
      throw error;
    }
  }

  // 获取统计信息
  async getMetrics() {
    try {
      const queries = [
        'SELECT COUNT(*) as total_rules FROM sanitization_rules',
        'SELECT COUNT(*) as enabled_rules FROM sanitization_rules WHERE enabled = true',
        'SELECT COUNT(*) as disabled_rules FROM sanitization_rules WHERE enabled = false',
        `SELECT
           CASE
             WHEN condition->>'type' = 'regex' THEN 'PATTERN'
             WHEN condition->>'type' = 'key_keyword' THEN 'FIELD_NAME'
             ELSE 'UNKNOWN'
           END as type_normalized,
           COUNT(*) as count
         FROM sanitization_rules
         GROUP BY condition->>'type'`,
        `SELECT
           COALESCE(sensitivity, 'unknown') as severity_level,
           COUNT(*) as count
         FROM sanitization_rules
         GROUP BY sensitivity`
      ];

      const results = await Promise.all(queries.map(query => db.query(query)));

      const rulesByType = {};
      results[3].rows.forEach(row => {
        const type = row.type_normalized || 'UNKNOWN';
        rulesByType[type] = (rulesByType[type] || 0) + parseInt(row.count);
      });

      const rulesBySeverity = {};
      results[4].rows.forEach(row => {
        const severity = row.severity_level.toUpperCase();
        rulesBySeverity[severity] = parseInt(row.count);
      });

      return {
        totalRules: parseInt(results[0].rows[0].total_rules),
        enabledRules: parseInt(results[1].rows[0].enabled_rules),
        disabledRules: parseInt(results[2].rows[0].disabled_rules),
        rulesByType,
        rulesBySeverity
      };
    } catch (error) {
      console.error('Error getting metrics:', error);
      throw error;
    }
  }

  // 数据转换辅助方法

  // 将数据库行转换为规则对象
  transformDbRowToRule(row) {
    const rule = {
      id: row.id,
      name: row.name,
      description: row.description,
      enabled: row.enabled,
      priority: row.priority,
      category: row.category,
      sensitivity: row.sensitivity,
      condition: row.condition,
      action: row.action,
      includeServices: row.include_services,
      excludeServices: row.exclude_services,
      conditions: row.conditions,
      metadata: row.metadata || {
        createdAt: row.created_at,
        updatedAt: row.updated_at,
        version: row.version || '1.0',
        author: row.created_by || 'system'
      },
      createdAt: row.created_at,
      updatedAt: row.updated_at
    };

    return rule;
  }

  // 将规则对象转换为数据库格式
  transformRuleToDbFormat(ruleData, ruleId, timestamp, isUpdate = false) {
    const dbData = {
      id: ruleId,
      name: ruleData.name,
      description: ruleData.description,
      enabled: ruleData.enabled !== undefined ? ruleData.enabled : true,
      priority: ruleData.priority || 0,
      category: ruleData.category,
      created_at: isUpdate ? undefined : timestamp,
      updated_at: timestamp,
      created_by: ruleData.createdBy || (ruleData.metadata && ruleData.metadata.author) || 'system',
      version: ruleData.version || (ruleData.metadata && ruleData.metadata.version) || '1.0'
    };

    // 处理规则数据
    dbData.sensitivity = ruleData.sensitivity;
    dbData.condition = JSON.stringify(ruleData.condition);
    dbData.action = JSON.stringify(ruleData.action);
    dbData.include_services = ruleData.includeServices;
    dbData.exclude_services = ruleData.excludeServices;
    dbData.conditions = ruleData.conditions ? JSON.stringify(ruleData.conditions) : null;
    dbData.metadata = JSON.stringify(ruleData.metadata || {
      createdAt: timestamp,
      updatedAt: timestamp,
      version: dbData.version,
      author: dbData.created_by
    });

    return dbData;
  }
}

module.exports = new SanitizationDAO();
