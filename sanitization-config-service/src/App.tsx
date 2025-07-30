import { Download, Edit, Plus, Search, Trash2 } from 'lucide-react';
import { useEffect, useState } from 'react';
import { Toaster, toast } from 'react-hot-toast';
import RuleEditModal from './components/RuleEditModal';
import Sidebar from './components/Sidebar';
import ToggleSwitch from './components/ToggleSwitch';
import { sanitizationApi } from './services/api';
import { SanitizationConfig } from './types';

function App() {
  const [config, setConfig] = useState<SanitizationConfig | null>(null);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [operationLoading, setOperationLoading] = useState(false);
  const [globalEnabled, setGlobalEnabled] = useState(true);
  const [isEditModalOpen, setIsEditModalOpen] = useState(false);
  const [editingRule, setEditingRule] = useState<any>(null);
  const [modalMode, setModalMode] = useState<'create' | 'edit'>('create');

  useEffect(() => {
    fetchRules();
  }, []);

  const fetchRules = async () => {
    try {
      setLoading(true);

      // 尝试读取新格式的规则
      try {
        const response = await fetch('/rules.json');
        if (response.ok) {
          const newFormatRules = await response.json();

          // 从后端API获取真实的全局状态
          let globalState = true;
          try {
            const backendResponse = await sanitizationApi.getRules();
            globalState = backendResponse.enabled;
          } catch (apiError) {
            console.warn('Failed to get global state from API, using default:', apiError);
            // 尝试从localStorage获取全局状态
            const savedGlobalState = localStorage.getItem('sanitization_global_enabled');
            if (savedGlobalState !== null) {
              globalState = JSON.parse(savedGlobalState);
            }
          }

          // 尝试从localStorage加载已保存的状态
          try {
            const savedRules = localStorage.getItem('sanitization_new_format_rules');
            if (savedRules) {
              const parsedSavedRules = JSON.parse(savedRules);
              // 合并保存的状态（主要是enabled状态）到原始规则中
              const mergedRules = newFormatRules.map((rule: any) => {
                const savedRule = parsedSavedRules.find((saved: any) => saved.id === rule.id);
                return savedRule ? { ...rule, enabled: savedRule.enabled, updatedAt: savedRule.updatedAt } : rule;
              });

              setConfig({
                enabled: globalState,
                rules: mergedRules
              });
            } else {
              setConfig({
                enabled: globalState,
                rules: newFormatRules
              });
            }
          } catch (error) {
            console.warn('Failed to load saved rules from localStorage:', error);
            setConfig({
              enabled: globalState,
              rules: newFormatRules
            });
          }

          setGlobalEnabled(globalState);
          return;
        }
      } catch (error) {
        console.warn('Failed to load new format rules, falling back to API');
      }

      // 回退到API调用
      const data = await sanitizationApi.getRules();
      setConfig(data);
      setGlobalEnabled(data.enabled);
    } catch (error) {
      toast.error('获取规则失败');
      console.error('Error fetching rules:', error);
    } finally {
      setLoading(false);
    }
  };

  const toggleRule = async (ruleId: string, enabled: boolean) => {
    if (operationLoading) return; // 防止重复操作

    try {
      setOperationLoading(true);

      // 先调用API同步到数据库
      try {
        await sanitizationApi.toggleRule(ruleId, enabled);
        toast.success(`规则已${enabled ? '启用' : '禁用'}`);
      } catch (error) {
        console.warn('API call failed, falling back to local storage:', error);
        toast.success(`规则已${enabled ? '启用' : '禁用'}（本地模式）`);
      }

      // 然后更新UI状态
      if (config) {
        const updatedConfig = {
          ...config,
          rules: config.rules.map(rule =>
            rule.id === ruleId
              ? { ...rule, enabled, updatedAt: new Date().toISOString() }
              : rule
          )
        };
        setConfig(updatedConfig);

        // 同时保存到localStorage作为备份
        try {
          const hasNewFormat = updatedConfig.rules.some(rule => (rule as any).condition);
          if (hasNewFormat) {
            localStorage.setItem('sanitization_new_format_rules', JSON.stringify(updatedConfig.rules));
          }
        } catch (error) {
          console.warn('Failed to save new format rules to localStorage:', error);
        }
      }
    } catch (error) {
      // 如果整个操作失败，回滚状态
      await fetchRules();
      toast.error('切换规则状态失败');
    } finally {
      setOperationLoading(false);
    }
  };

  const deleteRule = async (ruleId: string) => {
    if (operationLoading) return; // 防止重复操作

    if (!window.confirm('确定要删除此规则吗？')) {
      return;
    }

    try {
      setOperationLoading(true);

      // 先调用API同步到数据库
      try {
        await sanitizationApi.deleteRule(ruleId);
        toast.success('规则删除成功');
      } catch (error) {
        console.warn('API call failed, falling back to local storage:', error);
        toast.success('规则删除成功（本地模式）');
      }

      // 然后更新UI状态
      if (config) {
        const updatedConfig = {
          ...config,
          rules: config.rules.filter(rule => rule.id !== ruleId)
        };
        setConfig(updatedConfig);

        // 同时保存到localStorage作为备份
        try {
          const hasNewFormat = updatedConfig.rules.some(rule => (rule as any).condition);
          if (hasNewFormat) {
            localStorage.setItem('sanitization_new_format_rules', JSON.stringify(updatedConfig.rules));
          }
        } catch (error) {
          console.warn('Failed to save new format rules to localStorage:', error);
        }
      }
    } catch (error) {
      // 如果整个操作失败，回滚状态
      await fetchRules();
      toast.error('删除规则失败');
    } finally {
      setOperationLoading(false);
    }
  };

    const toggleGlobalSwitch = async (enabled: boolean) => {
    if (operationLoading) return;

    try {
      setOperationLoading(true);

      // 先调用API同步到数据库
      try {
        await sanitizationApi.toggleGlobalSwitch(enabled);
        toast.success(`全局脱敏已${enabled ? '启用' : '禁用'}`);
      } catch (error) {
        console.warn('API call failed, falling back to local storage:', error);
        toast.success(`全局脱敏已${enabled ? '启用' : '禁用'}（本地模式）`);
      }

      // 然后更新UI状态
      setGlobalEnabled(enabled);
      if (config) {
        setConfig({
          ...config,
          enabled
        });
      }

      // 同时保存到localStorage作为备份
      localStorage.setItem('sanitization_global_enabled', JSON.stringify(enabled));
    } catch (error) {
      // 如果整个操作失败，回滚状态
      await fetchRules();
      toast.error('切换全局状态失败');
    } finally {
      setOperationLoading(false);
    }
  };

  const handleCreateRule = () => {
    setEditingRule(null);
    setModalMode('create');
    setIsEditModalOpen(true);
  };

  const handleEditRule = (rule: any) => {
    setEditingRule(rule);
    setModalMode('edit');
    setIsEditModalOpen(true);
  };

  const handleSaveRule = async (ruleData: any) => {
    try {
      setOperationLoading(true);

      if (modalMode === 'create') {
        // 先调用API创建规则
        try {
          await sanitizationApi.createRule(ruleData);
          toast.success('规则创建成功');
        } catch (error) {
          console.warn('API call failed, falling back to local storage:', error);
          toast.success('规则创建成功（本地模式）');
        }

        // 然后更新UI状态
        if (config) {
          const newRules = Array.isArray(config.rules) ? [...config.rules, ruleData] : [ruleData];
          const updatedConfig = {
            ...config,
            rules: newRules
          };
          setConfig(updatedConfig);

          // 同时保存到localStorage作为备份
          try {
            localStorage.setItem('sanitization_new_format_rules', JSON.stringify(newRules));
          } catch (error) {
            console.warn('Failed to save new format rules to localStorage:', error);
          }
        }
      } else {
        // 先调用API更新规则
        try {
          await sanitizationApi.updateRule(ruleData.id, ruleData);
          toast.success('规则更新成功');
        } catch (error) {
          console.warn('API call failed, falling back to local storage:', error);
          toast.success('规则更新成功（本地模式）');
        }

        // 然后更新UI状态
        if (config) {
          const updatedRules = config.rules.map((rule: any) =>
            rule.id === ruleData.id ? ruleData : rule
          );
          const updatedConfig = {
            ...config,
            rules: updatedRules
          };
          setConfig(updatedConfig);

          // 同时保存到localStorage作为备份
          try {
            localStorage.setItem('sanitization_new_format_rules', JSON.stringify(updatedRules));
          } catch (error) {
            console.warn('Failed to save new format rules to localStorage:', error);
          }
        }
      }

      setIsEditModalOpen(false);
      setEditingRule(null);
    } catch (error) {
      toast.error('保存规则失败');
    } finally {
      setOperationLoading(false);
    }
  };

  const filteredRules = config?.rules.filter(rule =>
    rule.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    rule.description.toLowerCase().includes(searchTerm.toLowerCase())
  ) || [];

    // 按敏感级别和优先级排序规则
  const sortedRules = [...filteredRules].sort((a: any, b: any) => {
    // 敏感级别排序权重：critical > high > medium > low
    const sensitivityOrder = { 'critical': 1, 'high': 2, 'medium': 3, 'low': 4 };
    const getSensitivityWeight = (rule: any) => {
      const sensitivity = rule.sensitivity || rule.severity?.toLowerCase() || 'medium';
      return sensitivityOrder[sensitivity as keyof typeof sensitivityOrder] || 3;
    };

    const aSensitivity = getSensitivityWeight(a);
    const bSensitivity = getSensitivityWeight(b);

    // 先按敏感级别排序
    if (aSensitivity !== bSensitivity) {
      return aSensitivity - bSensitivity;
    }

    // 敏感级别相同时，按优先级排序（数字越小优先级越高）
    const aPriority = a.priority || 99;
    const bPriority = b.priority || 99;
    return aPriority - bPriority;
  });

  // 规则类型映射函数
  const getRuleTypeText = (type: string) => {
    const typeMap: Record<string, string> = {
      'regex': '正则表达式',
      'key_keyword': '字段关键词'
    };
    return typeMap[type] || type;
  };

  // 数据类别映射函数
  const getCategoryText = (category: string) => {
    const categoryMap: Record<string, string> = {
      'personal_info': '个人信息',
      'financial': '金融信息',
      'security': '安全信息',
      'medical': '医疗信息',
      'business': '商业信息',
      'other': '其他'
    };
    return categoryMap[category] || category;
  };

  // 敏感级别映射函数
  const getSensitivityText = (sensitivity: string) => {
    const sensitivityMap: Record<string, string> = {
      'low': '低',
      'medium': '中',
      'high': '高',
      'critical': '严重'
    };
    return sensitivityMap[sensitivity] || sensitivity;
  };

  const RulesTable = ({ rules }: { rules: any[] }) => (
    <div className="card shadow-modern">
      <table className="w-full text-left">
        <thead className="bg-gray-50 border-b border-gray-200">
          <tr>
            <th className="table-header-left">规则名称</th>
            <th className="table-header">类型</th>
            <th className="table-header">类别</th>
            <th className="table-header">敏感级别</th>
            <th className="table-header">优先级</th>
            <th className="table-header">状态</th>
            <th className="table-header">操作</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-gray-200">
          {sortedRules.map((rule) => (
            <tr key={rule.id} className="table-row">
              <td className="table-cell-left">
                <div className="font-medium text-gray-900">{rule.name}</div>
                <div className="text-sm text-gray-500 mt-1">{rule.description}</div>
              </td>
              <td className="table-cell">
                <span className="badge-gray">{getRuleTypeText((rule as any).condition?.type || (rule as any).type)}</span>
              </td>
              <td className="table-cell">
                <span className="badge-gray">{getCategoryText((rule as any).category)}</span>
              </td>
              <td className="table-cell">
                <span className={`px-2 py-1 text-xs rounded-full ${
                  ((rule as any).sensitivity === 'critical' || (rule as any).severity === 'CRITICAL') ? 'bg-red-100 text-red-800' :
                  ((rule as any).sensitivity === 'high' || (rule as any).severity === 'HIGH') ? 'bg-orange-100 text-orange-800' :
                  ((rule as any).sensitivity === 'medium' || (rule as any).severity === 'MEDIUM') ? 'bg-yellow-100 text-yellow-800' :
                  'bg-green-100 text-green-800'
                }`}>
                  {getSensitivityText((rule as any).sensitivity || (rule as any).severity)}
                </span>
              </td>
              <td className="table-cell">
                <span className="text-sm font-medium text-gray-600">
                  {(rule as any).priority || 10}
                </span>
              </td>
              <td className="table-cell">
                <div className="flex justify-center">
                  <ToggleSwitch
                    enabled={rule.enabled}
                    onChange={(enabled) => toggleRule(rule.id, enabled)}
                    disabled={operationLoading || !globalEnabled}
                  />
                </div>
              </td>
              <td className="table-cell">
                <div className="flex items-center justify-center space-x-2">
                  <button
                    onClick={() => handleEditRule(rule)}
                    disabled={!globalEnabled}
                    className={`btn-ghost p-2 rounded-lg ${
                      !globalEnabled ? 'opacity-50 cursor-not-allowed' : ''
                    }`}
                    title={!globalEnabled ? '全局脱敏已关闭' : '编辑'}
                  >
                    <Edit className="h-4 w-4" />
                  </button>
                  <button
                    onClick={() => deleteRule(rule.id)}
                    disabled={operationLoading || !globalEnabled}
                    className={`btn-ghost p-2 rounded-lg text-error-600 hover:text-error-700 hover:bg-error-50 ${
                      (operationLoading || !globalEnabled) ? 'opacity-50 cursor-not-allowed' : ''
                    }`}
                    title={
                      !globalEnabled ? '全局脱敏已关闭' :
                      operationLoading ? '操作中...' : '删除'
                    }
                  >
                    <Trash2 className="h-4 w-4" />
                  </button>
                </div>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-50 to-gray-100">
      <Toaster
        position="top-right"
        toastOptions={{
          duration: 3000,
          style: {
            background: '#ffffff',
            color: '#374151',
            boxShadow: '0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 8px 10px -6px rgba(0, 0, 0, 0.1)',
            borderRadius: '12px',
            border: '1px solid #e5e7eb',
            fontSize: '14px',
            fontWeight: '500'
          }
        }}
      />
      <Sidebar config={config} onConfigChange={fetchRules} />
      <main className="ml-64 p-6 lg:p-8 fade-in">
        <div className="container-responsive">
          {loading ? (
            <div className="empty-state">
              <div className="spinner h-12 w-12 mx-auto"></div>
              <p className="mt-4 text-gray-600">正在加载规则...</p>
            </div>
          ) : (
            <div className="space-y-6">
              {/* 页面标题区域 */}
              <div className="mb-8">
                <div className="flex items-center justify-between">
                  <div>
                    <h1 className="text-heading-1 mb-2">规则管理</h1>
                    <p className="text-body text-gray-600">管理和配置数据脱敏规则</p>
                  </div>
                  <div className="flex items-center space-x-4">
                    <div className="flex items-center space-x-3">
                      <span className={`text-sm font-medium ${globalEnabled ? 'text-success-600' : 'text-gray-500'}`}>
                        全局脱敏
                      </span>
                      <ToggleSwitch
                        enabled={globalEnabled}
                        onChange={toggleGlobalSwitch}
                        disabled={operationLoading}
                      />
                    </div>
                    <div className={`px-3 py-1 rounded-full text-xs font-medium ${
                      globalEnabled
                        ? 'bg-success-100 text-success-700'
                        : 'bg-gray-100 text-gray-600'
                    }`}>
                      {globalEnabled ? '已启用' : '已禁用'}
                    </div>
                  </div>
                </div>
              </div>

              {/* 搜索和操作区域 */}
              <div className="search-action-container mb-6">
                <div className="search-input-container">
                  <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400 pointer-events-none z-10" />
                  <input
                    type="text"
                    placeholder="搜索规则..."
                    value={searchTerm}
                    onChange={(e) => setSearchTerm(e.target.value)}
                    className="input-search w-full pl-12"
                  />
                </div>
                <div className="action-buttons-container">
                  <div className="flex items-center space-x-2 mr-4">
                    <button
                      onClick={async () => {
                        if (!config || operationLoading) return;

                        try {
                          setOperationLoading(true);
                          const allRuleIds = config.rules.map(r => r.id);

                          // 先调用API同步到数据库
                          try {
                            await sanitizationApi.batchOperation(allRuleIds, 'enable');
                            toast.success('已启用所有规则');
                          } catch (error) {
                            console.warn('API call failed, falling back to local storage:', error);
                            toast.success('已启用所有规则（本地模式）');
                          }

                          // 然后更新UI状态
                          const updatedConfig = {
                            ...config,
                            rules: config.rules.map(rule => ({
                              ...rule,
                              enabled: true,
                              updatedAt: new Date().toISOString()
                            }))
                          };
                          setConfig(updatedConfig);

                          // 同时保存到localStorage作为备份
                          try {
                            const hasNewFormat = updatedConfig.rules.some(rule => (rule as any).condition);
                            if (hasNewFormat) {
                              localStorage.setItem('sanitization_new_format_rules', JSON.stringify(updatedConfig.rules));
                            }
                          } catch (error) {
                            console.warn('Failed to save new format rules to localStorage:', error);
                          }
                        } catch (error) {
                          await fetchRules();
                          toast.error('批量启用失败');
                        } finally {
                          setOperationLoading(false);
                        }
                      }}
                      disabled={operationLoading || !globalEnabled}
                      className={`btn-secondary text-xs px-3 py-1 ${
                        (!globalEnabled || operationLoading) ? 'opacity-50 cursor-not-allowed' : ''
                      }`}
                      title={
                        !globalEnabled ? '全局脱敏已关闭' :
                        operationLoading ? '操作中...' : '启用所有规则'
                      }
                    >
                      全部启用
                    </button>
                    <button
                      onClick={async () => {
                        if (!config || operationLoading) return;

                        try {
                          setOperationLoading(true);
                          const allRuleIds = config.rules.map(r => r.id);

                          // 先调用API同步到数据库
                          try {
                            await sanitizationApi.batchOperation(allRuleIds, 'disable');
                            toast.success('已禁用所有规则');
                          } catch (error) {
                            console.warn('API call failed, falling back to local storage:', error);
                            toast.success('已禁用所有规则（本地模式）');
                          }

                          // 然后更新UI状态
                          const updatedConfig = {
                            ...config,
                            rules: config.rules.map(rule => ({
                              ...rule,
                              enabled: false,
                              updatedAt: new Date().toISOString()
                            }))
                          };
                          setConfig(updatedConfig);

                          // 同时保存到localStorage作为备份
                          try {
                            const hasNewFormat = updatedConfig.rules.some(rule => (rule as any).condition);
                            if (hasNewFormat) {
                              localStorage.setItem('sanitization_new_format_rules', JSON.stringify(updatedConfig.rules));
                            }
                          } catch (error) {
                            console.warn('Failed to save new format rules to localStorage:', error);
                          }
                        } catch (error) {
                          await fetchRules();
                          toast.error('批量禁用失败');
                        } finally {
                          setOperationLoading(false);
                        }
                      }}
                      disabled={operationLoading || !globalEnabled}
                      className={`btn-secondary text-xs px-3 py-1 ${
                        (!globalEnabled || operationLoading) ? 'opacity-50 cursor-not-allowed' : ''
                      }`}
                      title={
                        !globalEnabled ? '全局脱敏已关闭' :
                        operationLoading ? '操作中...' : '禁用所有规则'
                      }
                    >
                      全部禁用
                    </button>
                  </div>
                  <button
                    onClick={async () => {
                      try {
                        const configData = await sanitizationApi.exportRules();
                        const dataStr = JSON.stringify(configData, null, 2);
                        const dataBlob = new Blob([dataStr], { type: 'application/json' });
                        const url = URL.createObjectURL(dataBlob);
                        const link = document.createElement('a');
                        link.href = url;
                        link.download = `sanitization-config-${new Date().toISOString().split('T')[0]}.json`;
                        document.body.appendChild(link);
                        link.click();
                        document.body.removeChild(link);
                        URL.revokeObjectURL(url);
                        toast.success('配置文件导出成功');
                      } catch (error) {
                        toast.error('导出配置失败');
                      }
                    }}
                    className="btn-secondary mr-2"
                  >
                    <Download className="h-4 w-4" />
                    <span>导出配置</span>
                  </button>
                  <button
                    onClick={async () => {
                      if (operationLoading) return;

                      if (window.confirm('确定要重置为默认配置吗？这将清除所有自定义规则并恢复默认设置。')) {
                        try {
                          setOperationLoading(true);

                          // 调用重置API
                          const response = await sanitizationApi.resetToDefaults();
                          if (response.success) {
                            // 清理所有localStorage数据
                            localStorage.removeItem('sanitization_new_format_rules');
                            localStorage.removeItem('sanitization_rules');
                            localStorage.removeItem('sanitization_config');
                            localStorage.removeItem('sanitization_global_enabled');

                            // 重新获取数据
                            await fetchRules();
                            toast.success('已重置为默认配置');
                          } else {
                            throw new Error(response.message || '重置失败');
                          }
                        } catch (error) {
                          console.error('Reset failed:', error);
                          toast.error('重置失败: ' + (error as Error).message);
                        } finally {
                          setOperationLoading(false);
                        }
                      }
                    }}
                    disabled={operationLoading}
                    className={`btn-secondary mr-2 ${
                      operationLoading ? 'opacity-50 cursor-not-allowed' : ''
                    }`}
                    title={operationLoading ? '操作中...' : '重置为默认配置'}
                  >
                    {operationLoading ? '重置中...' : '重置配置'}
                  </button>
                  <button
                    onClick={handleCreateRule}
                    className="btn-primary"
                  >
                    <Plus className="h-5 w-5" />
                    <span>添加规则</span>
                  </button>
                </div>
              </div>

              {/* 规则统计卡片 */}
              {config && (
                <div className="grid grid-cols-1 md:grid-cols-5 gap-4 mb-6">
                  <div className={`card p-4 ${globalEnabled ? 'ring-2 ring-success-200' : 'ring-2 ring-gray-200'}`}>
                    <div className={`text-2xl font-bold ${globalEnabled ? 'text-success-600' : 'text-gray-400'}`}>
                      {globalEnabled ? '启用' : '禁用'}
                    </div>
                    <div className="text-sm text-gray-500">全局状态</div>
                  </div>
                  <div className="card p-4">
                    <div className="text-2xl font-bold text-gray-900">{config.rules.length}</div>
                    <div className="text-sm text-gray-500">总规则数</div>
                  </div>
                  <div className="card p-4">
                    <div className="text-2xl font-bold text-success-600">
                      {config.rules.filter(r => r.enabled).length}
                    </div>
                    <div className="text-sm text-gray-500">已启用</div>
                  </div>
                  <div className="card p-4">
                    <div className="text-2xl font-bold text-gray-600">
                      {config.rules.filter(r => !r.enabled).length}
                    </div>
                    <div className="text-sm text-gray-500">已禁用</div>
                  </div>
                  <div className="card p-4">
                    <div className="text-2xl font-bold text-error-600">
                      {config.rules.filter(r => (r as any).severity === 'CRITICAL' || (r as any).sensitivity === 'critical').length}
                    </div>
                    <div className="text-sm text-gray-500">高敏感级别</div>
                  </div>
                </div>
              )}

              {/* 规则列表 */}
              {filteredRules.length > 0 ? (
                <div className={`relative ${!globalEnabled ? 'opacity-60' : ''}`}>
                  {!globalEnabled && (
                    <div className="absolute inset-0 bg-gray-50 bg-opacity-50 z-10 flex items-center justify-center">
                      <div className="bg-white px-4 py-2 rounded-lg shadow-md border">
                        <p className="text-sm text-gray-600">全局脱敏已关闭，规则配置暂不可用</p>
                      </div>
                    </div>
                  )}
                  <RulesTable rules={sortedRules} />
                </div>
              ) : (
                <div className="empty-state">
                  <div className="empty-state-icon">
                    <Search className="h-12 w-12" />
                  </div>
                  <h3 className="empty-state-title">未找到规则</h3>
                  <p className="empty-state-description">
                    {searchTerm ? '尝试调整搜索条件' : '开始创建您的第一个脱敏规则'}
                  </p>
                  {!searchTerm && (
                    <button className="btn-primary mt-4">
                      <Plus className="h-5 w-5" />
                      <span>添加规则</span>
                    </button>
                  )}
                </div>
              )}
            </div>
          )}
        </div>
      </main>

      {/* 规则编辑Modal */}
      <RuleEditModal
        isOpen={isEditModalOpen}
        onClose={() => {
          setIsEditModalOpen(false);
          setEditingRule(null);
        }}
        onSave={handleSaveRule}
        rule={editingRule}
        mode={modalMode}
      />
    </div>
  );
}

export default App;
