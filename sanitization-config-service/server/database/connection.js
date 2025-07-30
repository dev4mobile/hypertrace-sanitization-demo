const { Pool } = require('pg');
require('dotenv').config();

class DatabaseConnection {
  constructor() {
    this.pool = null;
    this.isConnected = false;
  }

  // 初始化数据库连接池
  async initialize() {
    try {
      const dbConfig = {
        host: process.env.DB_HOST || 'localhost',
        port: process.env.DB_PORT || 5432,
        database: process.env.DB_NAME || 'sanitization_config',
        user: process.env.DB_USER || 'postgres',
        password: process.env.DB_PASSWORD || 'postgres',
        // 连接池配置
        max: parseInt(process.env.DB_POOL_MAX || '10'), // 最大连接数
        min: parseInt(process.env.DB_POOL_MIN || '2'),  // 最小连接数
        idleTimeoutMillis: parseInt(process.env.DB_IDLE_TIMEOUT || '30000'),
        connectionTimeoutMillis: parseInt(process.env.DB_CONNECTION_TIMEOUT || '5000'),
        // SSL 配置
        ssl: process.env.DB_SSL === 'true' ? {
          rejectUnauthorized: false
        } : false
      };

      this.pool = new Pool(dbConfig);

      // 监听连接事件
      this.pool.on('connect', (client) => {
        console.log('🔗 New PostgreSQL client connected');
      });

      this.pool.on('error', (err, client) => {
        console.error('❌ PostgreSQL client error:', err);
      });

      // 测试连接
      const client = await this.pool.connect();
      await client.query('SELECT NOW()');
      client.release();

      this.isConnected = true;
      console.log('✅ PostgreSQL database connection established successfully');
      console.log(`📊 Database: ${dbConfig.database}@${dbConfig.host}:${dbConfig.port}`);

    } catch (error) {
      console.error('❌ Failed to initialize database connection:', error);
      this.isConnected = false;
      throw error;
    }
  }

  // 获取数据库客户端
  async getClient() {
    if (!this.pool) {
      throw new Error('Database connection not initialized');
    }
    return await this.pool.connect();
  }

  // 执行查询
  async query(text, params = []) {
    if (!this.pool) {
      throw new Error('Database connection not initialized');
    }

    const start = Date.now();
    try {
      const result = await this.pool.query(text, params);
      const duration = Date.now() - start;

      // 在开发环境下记录慢查询
      if (process.env.NODE_ENV !== 'production' && duration > 1000) {
        console.warn(`⚠️ Slow query detected (${duration}ms):`, text);
      }

      return result;
    } catch (error) {
      console.error('❌ Database query error:', error);
      throw error;
    }
  }

  // 执行事务
  async transaction(callback) {
    const client = await this.getClient();
    try {
      await client.query('BEGIN');
      const result = await callback(client);
      await client.query('COMMIT');
      return result;
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  // 检查连接健康状态
  async checkHealth() {
    try {
      if (!this.pool) {
        return { status: 'unhealthy', error: 'Pool not initialized' };
      }

      const result = await this.query('SELECT NOW() as current_time, version() as version');
      const stats = {
        totalConnections: this.pool.totalCount,
        idleConnections: this.pool.idleCount,
        waitingConnections: this.pool.waitingCount
      };

      return {
        status: 'healthy',
        timestamp: result.rows[0].current_time,
        version: result.rows[0].version,
        connectionStats: stats
      };
    } catch (error) {
      return {
        status: 'unhealthy',
        error: error.message
      };
    }
  }

  // 关闭连接池
  async close() {
    if (this.pool) {
      await this.pool.end();
      this.isConnected = false;
      console.log('🔌 Database connection closed');
    }
  }

  // 获取连接状态
  getConnectionStatus() {
    return {
      isConnected: this.isConnected,
      pool: this.pool ? {
        totalCount: this.pool.totalCount,
        idleCount: this.pool.idleCount,
        waitingCount: this.pool.waitingCount
      } : null
    };
  }
}

// 创建单例实例
const dbConnection = new DatabaseConnection();

module.exports = dbConnection;
