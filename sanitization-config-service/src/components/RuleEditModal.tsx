// @ts-nocheck
import { Plus, Save, Trash2, X } from 'lucide-react';
import React, { useEffect, useState } from 'react';

interface RuleEditModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSave: (rule: any) => void;
  rule?: any; // 现有规则用于编辑，为空则是新建
  mode: 'create' | 'edit';
}

const RuleEditModal: React.FC<RuleEditModalProps> = ({
  isOpen,
  onClose,
  onSave,
  rule,
  mode
}) => {
  // @ts-ignore
  const [formData, setFormData] = useState({
    id: '',
    name: '',
    description: '',
    enabled: true,
    priority: 10,
    category: 'personal_info',
    sensitivity: 'medium',
    condition: {
      type: 'key_keyword',
      pattern: '',
      keywords: [''],
      path: ''
    },
    action: {
      algorithm: 'mask',
      params: {
        maskChar: '*',
        prefix: 3,
        suffix: 4,
        keepDomain: false,
        type: 'sha256',
        salt: '',
        replacement: ''
      }
    }
  });

  // 用于存储所有匹配类型的数据，避免切换时丢失
  const [conditionData, setConditionData] = useState({
    key_keyword: {
      keywords: ['']
    },
    regex: {
      pattern: ''
    }
  });

  const [errors, setErrors] = useState<Record<string, string>>({});

  // 获取匹配类型的默认值
  const getDefaultConditionData = (type: string) => {
    switch (type) {
      case 'key_keyword':
        return { keywords: [''] };
      case 'regex':
        return { pattern: getDefaultRegexPattern() };
      default:
        return {};
    }
  };

  // 根据当前规则内容获取合适的正则表达式默认值
  const getDefaultRegexPattern = (rule?: any) => {
    const ruleData = rule || formData;
    const ruleName = ruleData.name ? ruleData.name.toLowerCase() : '';
    const ruleDescription = ruleData.description ? ruleData.description.toLowerCase() : '';
    const category = ruleData.category || '';

    // 根据规则名称和描述判断类型
    if (ruleName.includes('手机') || ruleName.includes('phone') || ruleName.includes('mobile') ||
        ruleDescription.includes('手机') || ruleDescription.includes('phone') || ruleDescription.includes('mobile')) {
      return '^1[3-9]\\d{9}$'; // 手机号正则
    }

    if (ruleName.includes('邮箱') || ruleName.includes('email') || ruleName.includes('mail') ||
        ruleDescription.includes('邮箱') || ruleDescription.includes('email') || ruleDescription.includes('mail')) {
      return '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$'; // 邮箱正则
    }

    if (ruleName.includes('身份证') || ruleName.includes('idcard') || ruleName.includes('identity') ||
        ruleDescription.includes('身份证') || ruleDescription.includes('idcard') || ruleDescription.includes('identity')) {
      return '^[1-9]\\d{17}$'; // 身份证号正则（18位）
    }

    if (ruleName.includes('信用卡') || ruleName.includes('银行卡') || ruleName.includes('card') ||
        ruleDescription.includes('信用卡') || ruleDescription.includes('银行卡') || ruleDescription.includes('card') ||
        category === 'financial') {
      return '^\\d{4}\\s?\\d{4}\\s?\\d{4}\\s?\\d{4}$'; // 信用卡号正则
    }

    // 根据类别提供默认值
    if (category === 'personal_info') {
      return '^[\\u4e00-\\u9fa5a-zA-Z0-9]+$'; // 个人信息通用正则
    }

    if (category === 'financial') {
      return '^\\d+$'; // 金融信息数字正则
    }

    // 默认通用正则
    return '^[\\s\\S]*$';
  };

  // 判断是否应该显示保留域名选项（只对邮箱相关规则显示）
  const shouldShowKeepDomainOption = () => {
    const { category, condition } = formData;

    // 如果是邮箱类别或包含邮箱关键词，则显示保留域名选项
    if (category === 'email') return true;

    if (condition.type === 'key_keyword' && condition.keywords) {
      const emailKeywords = ['email', 'mail', 'emailaddress', 'useremail', 'e_mail'];
      return condition.keywords.some(keyword =>
        emailKeywords.some(emailKw =>
          keyword.toLowerCase().includes(emailKw.toLowerCase())
        )
      );
    }

    return false;
  };

  // 转换旧格式规则为新格式
  const convertOldRuleToNewFormat = (oldRule: any) => {
    // 如果已经是新格式，直接返回
    if (oldRule.condition && oldRule.action) {
      return {
        ...oldRule,
        condition: {
          ...oldRule.condition,
          keywords: oldRule.condition.keywords && oldRule.condition.keywords.length > 0
            ? oldRule.condition.keywords
            : ['']
        }
      };
    }

    // 转换旧格式到新格式
    const newRule = {
      id: oldRule.id,
      name: oldRule.name,
      description: oldRule.description,
      enabled: oldRule.enabled,
      priority: oldRule.priority || 10,
      category: oldRule.type === 'PATTERN' ? 'personal_info' : 'personal_info',
      sensitivity: oldRule.severity === 'CRITICAL' ? 'critical' :
                   oldRule.severity === 'HIGH' ? 'high' :
                   oldRule.severity === 'MEDIUM' ? 'medium' : 'low',
      condition: {
        type: oldRule.pattern ? 'regex' : 'key_keyword',
        pattern: oldRule.pattern || '',
        keywords: oldRule.fieldNames || ['']
      },
      action: {
        algorithm: 'mask',
        params: {
          maskChar: '*',
          prefix: 3,
          suffix: 4,
          keepDomain: false,
          type: 'sha256',
          salt: '',
          replacement: ''
        }
      },
      metadata: {
        createdAt: oldRule.createdAt || new Date().toISOString(),
        updatedAt: oldRule.updatedAt || new Date().toISOString(),
        version: '1.0',
        author: 'admin'
      }
    };

    return newRule;
  };

  useEffect(() => {
    if (rule && mode === 'edit') {
      const convertedRule = convertOldRuleToNewFormat(rule);
      setFormData(convertedRule);

      // 初始化conditionData，保存所有类型的数据
      const newConditionData = {
        key_keyword: {
          keywords: convertedRule.condition.type === 'key_keyword'
            ? convertedRule.condition.keywords
            : ['']
        },
        regex: {
          pattern: convertedRule.condition.type === 'regex'
            ? convertedRule.condition.pattern
            : getDefaultRegexPattern(convertedRule)
        }
      };
      setConditionData(newConditionData);
    } else if (mode === 'create') {
      // 生成新的规则ID
      const newId = `rule_${Date.now().toString().slice(-6)}`;
      setFormData(prev => ({
        ...prev,
        id: newId
      }));

      // 重置conditionData为默认值
      setConditionData({
        key_keyword: { keywords: [''] },
        regex: { pattern: '' }
      });
    }
  }, [rule, mode, isOpen]);

  const validateForm = (): boolean => {
    const newErrors: Record<string, string> = {};

    if (!formData.name.trim()) {
      newErrors.name = '规则名称不能为空';
    }

    if (!formData.description.trim()) {
      newErrors.description = '规则描述不能为空';
    }

    if (formData.condition.type === 'regex' && !formData.condition.pattern.trim()) {
      newErrors.pattern = '正则表达式不能为空';
    }

    if (formData.condition.type === 'key_keyword') {
      // @ts-ignore
      const validKeywords = formData.condition.keywords.filter((k: any) => k.trim());
      if (validKeywords.length === 0) {
        newErrors.keywords = '至少需要一个关键词';
      }
    }

    if (formData.condition.type === 'regex') {
      try {
        new RegExp(formData.condition.pattern);
      } catch (e) {
        newErrors.pattern = '无效的正则表达式';
      }
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSave = () => {
    if (!validateForm()) return;

    const ruleToSave = {
      ...formData,
      condition: {
        ...formData.condition,
        keywords: formData.condition.type === 'key_keyword'
          // @ts-ignore
          ? formData.condition.keywords.filter((k: any) => k.trim())
          : undefined
      },
      metadata: {
        createdAt: rule?.metadata?.createdAt || new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        version: rule?.metadata?.version || '1.0',
        author: rule?.metadata?.author || 'admin'
      }
    };

    onSave(ruleToSave);
  };

  // 处理匹配类型切换，保存当前数据并设置新类型的数据
  const handleConditionTypeChange = (newType: string) => {
    // 保存当前类型的数据
    const currentType = formData.condition.type;
    const updatedConditionData = {
      ...conditionData,
      [currentType]: currentType === 'key_keyword'
        ? { keywords: formData.condition.keywords }
        : { pattern: formData.condition.pattern }
    };
    setConditionData(updatedConditionData);

    // 设置新类型的数据，如果没有则使用默认值
    const newConditionValue = updatedConditionData[newType] || getDefaultConditionData(newType);

    setFormData(prev => ({
      ...prev,
      condition: {
        ...prev.condition,
        type: newType,
        ...newConditionValue
      }
    }));
  };

  const addKeyword = () => {
    setFormData(prev => ({
      ...prev,
      condition: {
        ...prev.condition,
        keywords: [...prev.condition.keywords, '']
      }
    }));
  };

  const removeKeyword = (index: number) => {
    setFormData(prev => ({
      ...prev,
      condition: {
        ...prev.condition,
        keywords: prev.condition.keywords.filter((_, i) => i !== index)
      }
    }));
  };

  const updateKeyword = (index: number, value: string) => {
    setFormData(prev => ({
      ...prev,
      condition: {
        ...prev.condition,
        keywords: prev.condition.keywords.map((k, i) => i === index ? value : k)
      }
    }));
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg shadow-xl max-w-2xl w-full max-h-screen overflow-y-auto m-4">
        <div className="flex items-center justify-between p-6 border-b">
          <h2 className="text-xl font-semibold">
            {mode === 'create' ? '创建新规则' : '编辑规则'}
          </h2>
          <button
            onClick={onClose}
            className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="p-6 space-y-6">
          {/* 基本信息 */}
          <div className="space-y-4">
            <h3 className="text-lg font-medium text-gray-900">基本信息</h3>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                规则名称 *
              </label>
              <input
                type="text"
                value={formData.name}
                onChange={(e) => setFormData(prev => ({ ...prev, name: e.target.value }))}
                className={`w-full px-3 py-2 border rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent ${
                  errors.name ? 'border-red-300' : 'border-gray-300'
                }`}
                placeholder="输入规则名称"
              />
              {errors.name && <p className="text-red-500 text-sm mt-1">{errors.name}</p>}
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                规则描述 *
              </label>
              <textarea
                value={formData.description}
                onChange={(e) => setFormData(prev => ({ ...prev, description: e.target.value }))}
                rows={3}
                className={`w-full px-3 py-2 border rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent ${
                  errors.description ? 'border-red-300' : 'border-gray-300'
                }`}
                placeholder="详细描述该规则的作用"
              />
              {errors.description && <p className="text-red-500 text-sm mt-1">{errors.description}</p>}
            </div>

            <div className="grid grid-cols-3 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  数据类别
                </label>
                <select
                  value={formData.category}
                  onChange={(e) => setFormData(prev => ({ ...prev, category: e.target.value }))}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                >
                  <option value="personal_info">个人信息</option>
                  <option value="financial">金融信息</option>
                  <option value="security">安全信息</option>
                  <option value="medical">医疗信息</option>
                  <option value="business">商业信息</option>
                  <option value="other">其他</option>
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  敏感级别
                </label>
                <select
                  value={formData.sensitivity}
                  onChange={(e) => setFormData(prev => ({ ...prev, sensitivity: e.target.value }))}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                >
                  <option value="low">低</option>
                  <option value="medium">中</option>
                  <option value="high">高</option>
                  <option value="critical">严重</option>
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  优先级
                </label>
                <input
                  type="number"
                  min="1"
                  max="100"
                  value={formData.priority}
                  onChange={(e) => setFormData(prev => ({ ...prev, priority: parseInt(e.target.value) || 10 }))}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                />
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                启用状态
              </label>
              <div className="flex items-center h-10">
                <label className="flex items-center">
                  <input
                    type="checkbox"
                    checked={formData.enabled}
                    onChange={(e) => setFormData(prev => ({ ...prev, enabled: e.target.checked }))}
                    className="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
                  />
                  <span className="ml-2 text-sm text-gray-700">启用规则</span>
                </label>
              </div>
            </div>
          </div>

          {/* 匹配条件 */}
          <div className="space-y-4">
            <h3 className="text-lg font-medium text-gray-900">匹配条件</h3>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                匹配类型
              </label>
              <select
                value={formData.condition.type}
                onChange={(e) => handleConditionTypeChange(e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              >
                <option value="key_keyword">字段名关键词</option>
                <option value="regex">正则表达式</option>
              </select>
            </div>

            {formData.condition.type === 'regex' && (
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  正则表达式 *
                </label>
                <input
                  type="text"
                  value={formData.condition.pattern}
                  onChange={(e) => setFormData(prev => ({
                    ...prev,
                    condition: { ...prev.condition, pattern: e.target.value }
                  }))}
                  className={`w-full px-3 py-2 border rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent ${
                    errors.pattern ? 'border-red-300' : 'border-gray-300'
                  }`}
                  placeholder="例如: ^1[3-9]\\d{9}$（手机号）或 ^[1-9]\\d{17}$（身份证号）"
                />
                {errors.pattern && <p className="text-red-500 text-sm mt-1">{errors.pattern}</p>}
              </div>
            )}

            {formData.condition.type === 'key_keyword' && (
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  字段名关键词 *
                </label>
                <div className="space-y-2">
                  {formData.condition.keywords.map((keyword, index) => (
                    <div key={index} className="flex items-center space-x-2">
                      <input
                        type="text"
                        value={keyword}
                        onChange={(e) => updateKeyword(index, e.target.value)}
                        className="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                        placeholder="输入字段名关键词，如：phone, mobile, email 等"
                      />
                      {formData.condition.keywords.length > 1 && (
                        <button
                          type="button"
                          onClick={() => removeKeyword(index)}
                          className="p-2 text-red-600 hover:bg-red-50 rounded-md transition-colors"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      )}
                    </div>
                  ))}
                  <button
                    type="button"
                    onClick={addKeyword}
                    className="flex items-center space-x-1 text-blue-600 hover:text-blue-700 text-sm"
                  >
                    <Plus className="w-4 h-4" />
                    <span>添加关键词</span>
                  </button>
                </div>
                {errors.keywords && <p className="text-red-500 text-sm mt-1">{errors.keywords}</p>}
              </div>
            )}


          </div>

          {/* 脱敏动作 */}
          <div className="space-y-4">
            <h3 className="text-lg font-medium text-gray-900">脱敏动作</h3>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                脱敏算法
              </label>
              <select
                value={formData.action.algorithm}
                onChange={(e) => setFormData(prev => ({
                  ...prev,
                  action: { ...prev.action, algorithm: e.target.value }
                }))}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              >
                <option value="mask">掩码处理</option>
                <option value="hash">哈希处理</option>
                <option value="encrypt">加密处理</option>
                <option value="replace">替换处理</option>
                <option value="remove">移除处理</option>
              </select>
            </div>

            {formData.action.algorithm === 'mask' && (
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    掩码字符
                  </label>
                  <input
                    type="text"
                    maxLength={1}
                    value={formData.action.params.maskChar}
                    onChange={(e) => setFormData(prev => ({
                      ...prev,
                      action: {
                        ...prev.action,
                        params: { ...prev.action.params, maskChar: e.target.value }
                      }
                    }))}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    placeholder="*"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    保留前缀字符数
                  </label>
                  <input
                    type="number"
                    min="0"
                    value={formData.action.params.prefix}
                    onChange={(e) => setFormData(prev => ({
                      ...prev,
                      action: {
                        ...prev.action,
                        params: { ...prev.action.params, prefix: parseInt(e.target.value) || 0 }
                      }
                    }))}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    保留后缀字符数
                  </label>
                  <input
                    type="number"
                    min="0"
                    value={formData.action.params.suffix}
                    onChange={(e) => setFormData(prev => ({
                      ...prev,
                      action: {
                        ...prev.action,
                        params: { ...prev.action.params, suffix: parseInt(e.target.value) || 0 }
                      }
                    }))}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  />
                </div>

                {shouldShowKeepDomainOption() && (
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      保留域名(邮箱)
                    </label>
                    <div className="flex items-center h-10">
                      <label className="flex items-center">
                        <input
                          type="checkbox"
                          checked={formData.action.params.keepDomain}
                          onChange={(e) => setFormData(prev => ({
                            ...prev,
                            action: {
                              ...prev.action,
                              params: { ...prev.action.params, keepDomain: e.target.checked }
                            }
                          }))}
                          className="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
                        />
                        <span className="ml-2 text-sm text-gray-700">保留域名</span>
                      </label>
                    </div>
                  </div>
                )}
              </div>
            )}

            {formData.action.algorithm === 'hash' && (
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    哈希类型
                  </label>
                  <select
                    value={formData.action.params.type || 'sha256'}
                    onChange={(e) => setFormData(prev => ({
                      ...prev,
                      action: {
                        ...prev.action,
                        params: { ...prev.action.params, type: e.target.value }
                      }
                    }))}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  >
                    <option value="md5">MD5</option>
                    <option value="sha256">SHA256</option>
                    <option value="sha512">SHA512</option>
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Salt值
                  </label>
                  <input
                    type="text"
                    value={formData.action.params.salt || ''}
                    onChange={(e) => setFormData(prev => ({
                      ...prev,
                      action: {
                        ...prev.action,
                        params: { ...prev.action.params, salt: e.target.value }
                      }
                    }))}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    placeholder="留空使用默认Salt值"
                  />
                </div>
              </div>
            )}

            {formData.action.algorithm === 'replace' && (
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  替换文本
                </label>
                <input
                  type="text"
                  value={formData.action.params.replacement || ''}
                  onChange={(e) => setFormData(prev => ({
                    ...prev,
                    action: {
                      ...prev.action,
                      params: { ...prev.action.params, replacement: e.target.value }
                    }
                  }))}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  placeholder="输入替换文本"
                />
              </div>
            )}
          </div>
        </div>

        <div className="flex items-center justify-end space-x-3 p-6 border-t bg-gray-50">
          <button
            onClick={onClose}
            className="px-4 py-2 text-gray-700 border border-gray-300 rounded-md hover:bg-gray-50 transition-colors"
          >
            取消
          </button>
          <button
            onClick={handleSave}
            className="flex items-center space-x-2 px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors"
          >
            <Save className="w-4 h-4" />
            <span>{mode === 'create' ? '创建规则' : '保存更改'}</span>
          </button>
        </div>
      </div>
    </div>
  );
};

export default RuleEditModal;
