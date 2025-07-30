import {
    ApiResponse,
    BatchOperationResponse,
    HealthResponse,
    MetricsResponse,
    SanitizationConfig,
    SanitizationRule,
    ValidationResponse
} from '../types';

// 配置
const API_BASE_URL = process.env.REACT_APP_API_URL || '';
const USE_BACKEND = process.env.REACT_APP_USE_BACKEND !== 'false';

// Local storage keys (用于回退到本地存储)
const STORAGE_KEYS = {
  RULES: 'sanitization_rules',
  CONFIG: 'sanitization_config',
  GLOBAL_ENABLED: 'sanitization_global_enabled'
};

// 检查后端服务是否可用
let backendAvailable = false;

const checkBackendAvailability = async (): Promise<boolean> => {
  if (!USE_BACKEND) return false;

  try {
    const response = await fetch(`${API_BASE_URL}/api/health`, {
      method: 'GET',
      timeout: 5000
    } as RequestInit);
    backendAvailable = response.ok;
    return backendAvailable;
  } catch (error) {
    console.warn('Backend service not available, falling back to local storage');
    backendAvailable = false;
    return false;
  }
};

// 初始化时检查后端可用性
checkBackendAvailability();

// Default configuration (用于本地存储回退) - 与后端数据库保持一致
const DEFAULT_CONFIG: SanitizationConfig = {
  enabled: true,
  rules: [
    // 邮箱脱敏
    {
      id: 'default-email-rule',
      name: '邮箱脱敏',
      description: '对邮箱地址进行脱敏处理，保留域名部分',
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
      },
      metadata: {
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        version: '1.0',
        author: 'system'
      }
    },
    // 手机号脱敏
    {
      id: 'default-phone-rule',
      name: '手机号脱敏',
      description: '对中国大陆手机号进行脱敏处理，保留前3位和后4位',
      enabled: true,
      priority: 10,
      category: 'personal_info',
      sensitivity: 'high',
      condition: {
        type: 'regex',
        pattern: '1[3-9]\\d{9}'
      },
      action: {
        algorithm: 'mask',
        params: {
          maskChar: '*',
          prefix: 3,
          suffix: 4
        }
      },
      metadata: {
      createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        version: '1.0',
        author: 'system'
      }
    },
    // 身份证脱敏
    {
      id: 'default-idcard-rule',
      name: '身份证脱敏',
      description: '对中国身份证号进行脱敏处理',
      enabled: true,
      priority: 5,
      category: 'personal_info',
      sensitivity: 'critical',
      condition: {
        type: 'regex',
        pattern: '[1-9]\\d{5}(18|19|20)\\d{2}((0[1-9])|(1[0-2]))(([0-2][1-9])|10|20|30|31)\\d{3}[0-9Xx]'
      },
      action: {
        algorithm: 'mask',
        params: {
          maskChar: '*',
          prefix: 3,
          suffix: 4
        }
      },
      metadata: {
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        version: '1.0',
        author: 'system'
      }
    },
    // 信用卡脱敏
    {
      id: 'default-credit-card-rule',
      name: '信用卡脱敏',
      description: '对信用卡号进行脱敏处理',
      enabled: true,
      priority: 5,
      category: 'financial',
      sensitivity: 'critical',
      condition: {
        type: 'regex',
        pattern: '\\b(?:\\d{4}[-\\s]?){3}\\d{4}\\b'
      },
      action: {
        algorithm: 'mask',
        params: {
          maskChar: '*',
          prefix: 3,
          suffix: 4
        }
      },
      metadata: {
      createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        version: '1.0',
        author: 'system'
      }
    }
  ]
};

// Utility functions for local storage (回退功能)
const getStoredData = <T>(key: string, defaultValue: T): T => {
  try {
    const stored = localStorage.getItem(key);
    return stored ? JSON.parse(stored) : defaultValue;
  } catch (error) {
    console.error(`Error reading from localStorage key ${key}:`, error);
    return defaultValue;
  }
};

const setStoredData = <T>(key: string, data: T): void => {
  try {
    localStorage.setItem(key, JSON.stringify(data));
  } catch (error) {
    console.error(`Error writing to localStorage key ${key}:`, error);
  }
};

// HTTP request helper
const apiRequest = async <T>(
  endpoint: string,
  options: RequestInit = {}
): Promise<T> => {
  const url = `${API_BASE_URL}${endpoint}`;
  const response = await fetch(url, {
    headers: {
      'Content-Type': 'application/json',
      ...options.headers,
    },
    ...options,
  });

  if (!response.ok) {
    const errorData = await response.json().catch(() => ({}));
    throw new Error(errorData.error || `HTTP ${response.status}: ${response.statusText}`);
  }

  return response.json();
};

// 本地存储实现 (回退功能)
const localStorageImplementation = {
  getRules: async (): Promise<SanitizationConfig> => {
    await new Promise(resolve => setTimeout(resolve, 100));
    const config = getStoredData(STORAGE_KEYS.CONFIG, DEFAULT_CONFIG);
    const globalEnabled = getStoredData(STORAGE_KEYS.GLOBAL_ENABLED, true);
    return { ...config, enabled: globalEnabled };
  },

  createRule: async (rule: SanitizationRule): Promise<ApiResponse<SanitizationRule>> => {
    await new Promise(resolve => setTimeout(resolve, 100));
    const config = getStoredData(STORAGE_KEYS.CONFIG, DEFAULT_CONFIG);
    const newRule: SanitizationRule = {
      ...rule,
      id: rule.id || `rule-${Date.now()}`,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };
    const updatedConfig = { ...config, rules: [...config.rules, newRule] };
    setStoredData(STORAGE_KEYS.CONFIG, updatedConfig);
    return { success: true, data: newRule, message: 'Rule created successfully' };
  },

  updateRule: async (ruleId: string, rule: SanitizationRule): Promise<ApiResponse<SanitizationRule>> => {
    await new Promise(resolve => setTimeout(resolve, 100));
    const config = getStoredData(STORAGE_KEYS.CONFIG, DEFAULT_CONFIG);
    const ruleIndex = config.rules.findIndex(r => r.id === ruleId);
    if (ruleIndex === -1) throw new Error('Rule not found');

    const updatedRule: SanitizationRule = {
      ...rule,
      id: ruleId,
      createdAt: (config.rules[ruleIndex] as any).createdAt || new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };
    const updatedConfig = {
      ...config,
      rules: config.rules.map((r, index) => index === ruleIndex ? updatedRule : r)
    };
    setStoredData(STORAGE_KEYS.CONFIG, updatedConfig);
    return { success: true, data: updatedRule, message: 'Rule updated successfully' };
  },

  deleteRule: async (ruleId: string): Promise<ApiResponse<any>> => {
    await new Promise(resolve => setTimeout(resolve, 100));
    const config = getStoredData(STORAGE_KEYS.CONFIG, DEFAULT_CONFIG);
    const updatedConfig = { ...config, rules: config.rules.filter(r => r.id !== ruleId) };
    setStoredData(STORAGE_KEYS.CONFIG, updatedConfig);
    return { success: true, data: null, message: 'Rule deleted successfully' };
  },

  toggleRule: async (ruleId: string, enabled: boolean): Promise<ApiResponse<SanitizationRule>> => {
    await new Promise(resolve => setTimeout(resolve, 100));
    const config = getStoredData(STORAGE_KEYS.CONFIG, DEFAULT_CONFIG);
    const ruleIndex = config.rules.findIndex(r => r.id === ruleId);
    if (ruleIndex === -1) throw new Error('Rule not found');

    const updatedRule = { ...config.rules[ruleIndex], enabled, updatedAt: new Date().toISOString() };
    const updatedConfig = {
      ...config,
      rules: config.rules.map((r, index) => index === ruleIndex ? updatedRule : r)
    };
    setStoredData(STORAGE_KEYS.CONFIG, updatedConfig);
    return { success: true, data: updatedRule, message: `Rule ${enabled ? 'enabled' : 'disabled'} successfully` };
  }
};

// 创建API对象
const createSanitizationApi = () => {
  const api = {
    // 检查后端可用性
    checkBackend: checkBackendAvailability,

    // 获取所有脱敏规则
    getRules: async (serviceName?: string): Promise<SanitizationConfig> => {
      if (backendAvailable) {
        try {
          const response = await apiRequest<{ success: boolean; data: SanitizationConfig }>('/api/config');
          return response.data;
        } catch (error) {
          console.warn('Backend request failed, falling back to local storage:', error);
          backendAvailable = false;
        }
      }
      return localStorageImplementation.getRules();
    },

    // 创建新规则
    createRule: async (rule: SanitizationRule): Promise<ApiResponse<SanitizationRule>> => {
      if (backendAvailable) {
        try {
          return await apiRequest<ApiResponse<SanitizationRule>>('/api/rules', {
            method: 'POST',
            body: JSON.stringify(rule)
          });
        } catch (error) {
          console.warn('Backend request failed, falling back to local storage:', error);
          backendAvailable = false;
        }
      }
      return localStorageImplementation.createRule(rule);
    },

    // 更新现有规则
    updateRule: async (ruleId: string, rule: SanitizationRule): Promise<ApiResponse<SanitizationRule>> => {
      if (backendAvailable) {
        try {
          return await apiRequest<ApiResponse<SanitizationRule>>(`/api/rules/${ruleId}`, {
            method: 'PUT',
            body: JSON.stringify(rule)
          });
        } catch (error) {
          console.warn('Backend request failed, falling back to local storage:', error);
          backendAvailable = false;
        }
      }
      return localStorageImplementation.updateRule(ruleId, rule);
    },

    // 删除规则
    deleteRule: async (ruleId: string): Promise<ApiResponse<any>> => {
      if (backendAvailable) {
        try {
          return await apiRequest<ApiResponse<any>>(`/api/rules/${ruleId}`, {
            method: 'DELETE'
          });
        } catch (error) {
          console.warn('Backend request failed, falling back to local storage:', error);
          backendAvailable = false;
        }
      }
      return localStorageImplementation.deleteRule(ruleId);
    },

    // 切换规则启用状态
    toggleRule: async (ruleId: string, enabled: boolean): Promise<ApiResponse<SanitizationRule>> => {
      if (backendAvailable) {
        try {
          // 获取当前规则
          const currentRules = await api.getRules();
          const rule = currentRules.rules.find((r: SanitizationRule) => r.id === ruleId);
          if (!rule) throw new Error('Rule not found');

          // 更新规则
          const updatedRule = { ...rule, enabled };
          return await api.updateRule(ruleId, updatedRule);
        } catch (error) {
          console.warn('Backend request failed, falling back to local storage:', error);
          backendAvailable = false;
        }
      }
      return localStorageImplementation.toggleRule(ruleId, enabled);
    },

    // 批量操作
    batchOperation: async (ruleIds: string[], operation: 'enable' | 'disable' | 'delete'): Promise<BatchOperationResponse> => {
      if (backendAvailable) {
        try {
          return await apiRequest<BatchOperationResponse>('/api/rules/batch', {
            method: 'POST',
            body: JSON.stringify({ ruleIds, operation })
          });
        } catch (error) {
          console.warn('Backend request failed, falling back to local storage:', error);
          backendAvailable = false;
        }
      }

      // 本地存储回退实现
      await new Promise(resolve => setTimeout(resolve, 200));
      const config = getStoredData(STORAGE_KEYS.CONFIG, DEFAULT_CONFIG);
      let updatedRules = [...config.rules];
      let successCount = 0;
      let failureCount = 0;

      for (const ruleId of ruleIds) {
        const ruleIndex = updatedRules.findIndex(r => r.id === ruleId);
        if (ruleIndex !== -1) {
          if (operation === 'delete') {
            updatedRules = updatedRules.filter(r => r.id !== ruleId);
          } else {
            updatedRules[ruleIndex] = {
              ...updatedRules[ruleIndex],
              enabled: operation === 'enable',
              updatedAt: new Date().toISOString()
            };
          }
          successCount++;
        } else {
          failureCount++;
        }
      }

      const updatedConfig = { ...config, rules: updatedRules };
      setStoredData(STORAGE_KEYS.CONFIG, updatedConfig);

      return {
        success: failureCount === 0,
        successCount,
        failureCount,
        message: `Batch operation completed: ${successCount} successful, ${failureCount} failed`
      };
    },

    // 验证规则配置
    validateRule: async (rule: SanitizationRule, testInput?: string): Promise<ValidationResponse> => {
      await new Promise(resolve => setTimeout(resolve, 100));

      const errors: string[] = [];

      // 基本验证
      if (!rule.name?.trim()) {
        errors.push('Rule name is required');
      }

      const ruleAny = rule as any;

      if (!ruleAny.type && !ruleAny.condition) {
        errors.push('Rule type or condition is required');
      }

      if (ruleAny.type === 'PATTERN' && !ruleAny.pattern?.trim()) {
        errors.push('Pattern is required for PATTERN type rules');
      }

          if (rule.condition.type === 'key_keyword' && (!rule.condition.keywords || rule.condition.keywords.length === 0)) {
      errors.push('Keywords are required for key_keyword type conditions');
    }

      // 模式验证
      if (ruleAny.type === 'PATTERN' && ruleAny.pattern) {
        try {
          new RegExp(ruleAny.pattern);
        } catch (e) {
          errors.push('Invalid regular expression pattern');
        }
      }

      if (ruleAny.condition?.type === 'regex' && ruleAny.condition?.pattern) {
        try {
          new RegExp(ruleAny.condition.pattern);
        } catch (e) {
          errors.push('Invalid regular expression pattern');
        }
      }

      // 测试输入验证
      let testResult = null;
      const testPattern = ruleAny.pattern || ruleAny.condition?.pattern;
      const maskValue = ruleAny.maskValue || '[MASKED]';

      if (testInput && testPattern && errors.length === 0) {
        try {
          const regex = new RegExp(testPattern, 'g');
          const matches = testInput.match(regex);
          testResult = {
            input: testInput,
            matches: matches || [],
            masked: matches ? testInput.replace(regex, maskValue) : testInput
          };
        } catch (e) {
          errors.push('Error testing pattern against input');
        }
      }

      return {
        valid: errors.length === 0,
        errors,
        testResult,
        message: errors.length === 0 ? 'Validation successful' : 'Validation failed',
        timestamp: Date.now(),
        testOutput: testResult ? testResult.masked : undefined
      };
    },

    // 重载规则
    reloadRules: async (): Promise<ApiResponse<any>> => {
      if (backendAvailable) {
        try {
          // 如果有后端服务，重新检查后端可用性
          await checkBackendAvailability();
          return { success: true, data: null, message: 'Rules reloaded from backend service' };
        } catch (error) {
          console.warn('Backend reload failed, resetting local storage:', error);
          backendAvailable = false;
        }
      }

      // 本地存储重置
      await new Promise(resolve => setTimeout(resolve, 100));
      setStoredData(STORAGE_KEYS.CONFIG, DEFAULT_CONFIG);
      return { success: true, data: null, message: 'Rules reloaded to default configuration' };
    },

    // 切换全局开关
    toggleGlobalSwitch: async (enabled: boolean): Promise<{ enabled: boolean; message: string; timestamp: number }> => {
      if (backendAvailable) {
        try {
          const response = await apiRequest<{ success: boolean; data: { enabled: boolean; timestamp: number }; message: string }>('/api/config/global-switch', {
            method: 'POST',
            body: JSON.stringify({ enabled })
          });

          // 同步状态到localStorage，确保刷新页面时状态一致
          setStoredData(STORAGE_KEYS.GLOBAL_ENABLED, response.data.enabled);

          return {
            enabled: response.data.enabled,
            message: response.message,
            timestamp: response.data.timestamp
          };
        } catch (error) {
          console.warn('Backend request failed, falling back to local storage:', error);
          backendAvailable = false;
        }
      }

      // 本地存储回退
      await new Promise(resolve => setTimeout(resolve, 100));
      setStoredData(STORAGE_KEYS.GLOBAL_ENABLED, enabled);
      return {
        enabled,
        message: `Global sanitization ${enabled ? 'enabled' : 'disabled'}`,
        timestamp: Date.now()
      };
    },

    // 获取服务健康状态
    getHealth: async (): Promise<HealthResponse> => {
      if (backendAvailable) {
        try {
          return await apiRequest<HealthResponse>('/api/health');
        } catch (error) {
          console.warn('Backend health check failed:', error);
          backendAvailable = false;
        }
      }

      // 本地存储回退
      await new Promise(resolve => setTimeout(resolve, 50));
      return {
        status: 'healthy',
        timestamp: new Date().toISOString(),
        version: '1.0.0',
        uptime: Date.now(),
        checks: {
          storage: 'healthy',
          memory: 'healthy'
        }
      };
    },

    // 获取服务指标
    getMetrics: async (): Promise<MetricsResponse> => {
      if (backendAvailable) {
        try {
          return await apiRequest<MetricsResponse>('/api/metrics');
        } catch (error) {
          console.warn('Backend metrics request failed:', error);
          backendAvailable = false;
        }
      }

      // 本地存储回退
      await new Promise(resolve => setTimeout(resolve, 50));
      const config = getStoredData(STORAGE_KEYS.CONFIG, DEFAULT_CONFIG);
      return {
        totalRules: config.rules.length,
        enabledRules: config.rules.filter(r => r.enabled).length,
        disabledRules: config.rules.filter(r => !r.enabled).length,
        rulesByType: {
          key_keyword: config.rules.filter(r => r.condition?.type === 'key_keyword').length,
          regex: config.rules.filter(r => r.condition?.type === 'regex').length
        },
        rulesBySeverity: {
          CRITICAL: config.rules.filter(r => (r as any).severity === 'CRITICAL' || (r as any).sensitivity === 'critical').length,
          HIGH: config.rules.filter(r => (r as any).severity === 'HIGH' || (r as any).sensitivity === 'high').length,
          MEDIUM: config.rules.filter(r => (r as any).severity === 'MEDIUM' || (r as any).sensitivity === 'medium').length,
          LOW: config.rules.filter(r => (r as any).severity === 'LOW' || (r as any).sensitivity === 'low').length
        }
      };
    },

    // 导出规则配置
    exportRules: async (): Promise<any> => {
      // 直接调用 /rules.json 端点，确保格式一致
      try {
        const response = await fetch('/rules.json');
        if (response.ok) {
          return await response.json();
        }
      } catch (error) {
        console.warn('Failed to fetch from /rules.json, falling back to API:', error);
      }

      // 回退到原有逻辑
      const config = await api.getRules();
      return config.rules || [];
    },

    // 导入规则配置
    importRules: async (config: SanitizationConfig): Promise<ApiResponse<any>> => {
      await new Promise(resolve => setTimeout(resolve, 200));

      if (!config || !Array.isArray(config.rules)) {
        throw new Error('Invalid configuration format');
      }

      const processedConfig = {
        ...config,
        rules: config.rules.map(rule => ({
          ...rule,
          createdAt: (rule as any).createdAt || (rule as any).metadata?.createdAt || new Date().toISOString(),
          updatedAt: new Date().toISOString()
        }))
      };

      setStoredData(STORAGE_KEYS.CONFIG, processedConfig);

      return {
        success: true,
        data: processedConfig,
        message: `Successfully imported ${config.rules.length} rules`
      };
    },

    // 重置为默认配置
    resetToDefaults: async (): Promise<ApiResponse<any>> => {
      if (backendAvailable) {
        try {
          const response = await apiRequest<ApiResponse<any>>('/api/config/reset', {
            method: 'POST'
          });
          return response;
        } catch (error) {
          console.warn('Backend reset failed, falling back to local storage:', error);
          backendAvailable = false;
        }
      }

      // 本地存储回退
      await new Promise(resolve => setTimeout(resolve, 100));
      localStorage.removeItem(STORAGE_KEYS.CONFIG);
      localStorage.removeItem(STORAGE_KEYS.GLOBAL_ENABLED);
      localStorage.removeItem('sanitization_new_format_rules');
      setStoredData(STORAGE_KEYS.CONFIG, DEFAULT_CONFIG);
      setStoredData(STORAGE_KEYS.GLOBAL_ENABLED, true);
      return { success: true, data: null, message: 'Successfully reset to default configuration' };
    },
  };

  return api;
};

export const sanitizationApi = createSanitizationApi();
