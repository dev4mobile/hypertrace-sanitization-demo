
import { BarChart3, Download, Settings, Shield, Upload, Users } from 'lucide-react';
import { useState } from 'react';
import { toast } from 'react-hot-toast';
import { sanitizationApi } from '../services/api';
import { SanitizationConfig } from '../types';

interface NavItem {
  id: string;
  label: string;
  icon: React.ComponentType<{ className?: string }>;
  active?: boolean;
  badge?: string;
}

interface SidebarProps {
  config: SanitizationConfig | null;
  onConfigChange?: () => void;
}

const Sidebar: React.FC<SidebarProps> = ({ config, onConfigChange }) => {
  const [activeItem, setActiveItem] = useState('rules');

  // 计算活跃规则数量
  const activeRulesCount = config ? config.rules.filter(rule => rule.enabled).length : 0;

  // 计算系统可用性
  const calculateAvailability = () => {
    if (!config) return 0;

    const totalRules = config.rules.length;
    const enabledRules = activeRulesCount;
    const criticalRules = config.rules.filter(r => (r as any).severity === 'CRITICAL' || (r as any).sensitivity === 'critical').length;
    const enabledCriticalRules = config.rules.filter(r => ((r as any).severity === 'CRITICAL' || (r as any).sensitivity === 'critical') && r.enabled).length;

    // 基础可用性：启用规则比例 (权重40%)
    const ruleAvailability = totalRules > 0 ? (enabledRules / totalRules) : 0;

    // 高敏感规则可用性：高敏感规则启用比例 (权重40%)
    const criticalAvailability = criticalRules > 0 ? (enabledCriticalRules / criticalRules) : 1;

    // 系统健康度：固定基础值 (权重20%)
    const systemHealth = 0.99;

    // 综合计算可用性
    const availability = (ruleAvailability * 0.4) + (criticalAvailability * 0.4) + (systemHealth * 0.2);

    return Math.min(availability * 100, 99.9); // 最高99.9%
  };

  const availabilityPercentage = calculateAvailability();

  const navItems: NavItem[] = [
    {
      id: 'rules',
      label: '规则管理',
      icon: Shield,
      active: activeItem === 'rules'
    },
    {
      id: 'settings',
      label: '全局设置',
      icon: Settings,
      active: activeItem === 'settings'
    },
    {
      id: 'analytics',
      label: '数据分析',
      icon: BarChart3,
      active: activeItem === 'analytics',
      badge: '新'
    },
    {
      id: 'users',
      label: '用户管理',
      icon: Users,
      active: activeItem === 'users'
    },
    {
      id: 'import',
      label: '导入配置',
      icon: Upload,
      active: activeItem === 'import'
    },
    {
      id: 'export',
      label: '导出配置',
      icon: Download,
      active: activeItem === 'export'
    }
  ];

  const handleNavClick = async (itemId: string) => {
    setActiveItem(itemId);

    // 处理导出配置
    if (itemId === 'export') {
      await handleExportConfig();
    }

    // 处理导入配置
    if (itemId === 'import') {
      handleImportConfig();
    }
  };

  const handleExportConfig = async () => {
    try {
      const configData = await sanitizationApi.exportRules();

      // 创建下载文件
      const dataStr = JSON.stringify(configData, null, 2);
      const dataBlob = new Blob([dataStr], { type: 'application/json' });

      // 创建下载链接
      const url = URL.createObjectURL(dataBlob);
      const link = document.createElement('a');
      link.href = url;
      link.download = `sanitization-config-${new Date().toISOString().split('T')[0]}.json`;

      // 触发下载
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);

      // 清理URL对象
      URL.revokeObjectURL(url);

      toast.success('配置文件导出成功');
    } catch (error) {
      console.error('Export failed:', error);
      toast.error('导出配置失败');
    }
  };

  const handleImportConfig = () => {
    // 创建文件输入元素
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = '.json';

    input.onchange = async (event) => {
      const file = (event.target as HTMLInputElement).files?.[0];
      if (!file) return;

      try {
        const text = await file.text();
        const configData = JSON.parse(text);

        // 验证配置格式
        if (!configData.rules || !Array.isArray(configData.rules)) {
          throw new Error('Invalid configuration format');
        }

        // 导入配置
        await sanitizationApi.importRules(configData);

        toast.success(`成功导入 ${configData.rules.length} 条规则`);

        // 刷新配置数据
        if (onConfigChange) {
          onConfigChange();
        }
      } catch (error) {
        console.error('Import failed:', error);
        toast.error('导入配置失败：文件格式不正确');
      }
    };

    // 触发文件选择
    input.click();
  };

  return (
    <aside className="sidebar">
      {/* 侧边栏头部 */}
      <div className="sidebar-header">
        <div className="flex items-center space-x-3">
          <div className="flex items-center justify-center w-10 h-10 bg-primary-600 rounded-xl">
            <Shield className="h-6 w-6 text-white" />
          </div>
          <div>
            <h1 className="text-xl font-bold text-gray-900">脱敏配置管理</h1>
            <p className="text-xs text-gray-500 mt-0.5">数据安全保护平台</p>
          </div>
        </div>
      </div>

      {/* 导航菜单 */}
      <nav className="sidebar-nav">
        <div className="space-y-1">
          {navItems.map((item) => {
            const Icon = item.icon;
            return (
              <button
                key={item.id}
                onClick={() => handleNavClick(item.id)}
                className={
                  item.active
                    ? 'nav-item-active w-full text-left'
                    : 'nav-item-inactive w-full text-left'
                }
              >
                <Icon className="h-5 w-5 flex-shrink-0" />
                <span className="flex-1">{item.label}</span>
                {item.badge && (
                  <span className="badge-info text-xs px-2 py-0.5">
                    {item.badge}
                  </span>
                )}
              </button>
            );
          })}
        </div>

        {/* 分隔线 */}
        <div className="divider my-6"></div>

        {/* 底部信息 */}
        <div className="px-3 py-4">
          <div className="bg-gray-50 rounded-lg p-4">
            <div className="flex items-center space-x-3">
              <div className={`w-8 h-8 rounded-full flex items-center justify-center ${
                availabilityPercentage >= 95 ? 'bg-success-100' :
                availabilityPercentage >= 85 ? 'bg-warning-100' : 'bg-error-100'
              }`}>
                <div className={`w-2 h-2 rounded-full ${
                  availabilityPercentage >= 95 ? 'bg-success-500' :
                  availabilityPercentage >= 85 ? 'bg-warning-500' : 'bg-error-500'
                }`}></div>
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium text-gray-900">系统状态</p>
                <p className={`text-xs truncate ${
                  availabilityPercentage >= 95 ? 'text-success-600' :
                  availabilityPercentage >= 85 ? 'text-warning-600' : 'text-error-600'
                }`}>
                  {availabilityPercentage >= 95 ? '运行正常' :
                   availabilityPercentage >= 85 ? '部分异常' : '需要关注'}
                </p>
              </div>
            </div>
            <div className="mt-3 grid grid-cols-2 gap-2 text-xs">
              <div className="text-center">
                <div className="font-semibold text-gray-900">{activeRulesCount}</div>
                <div className="text-gray-500">活跃规则</div>
              </div>
              <div className="text-center">
                <div className={`font-semibold ${
                  availabilityPercentage >= 95 ? 'text-success-600' :
                  availabilityPercentage >= 85 ? 'text-warning-600' : 'text-error-600'
                }`}>
                  {availabilityPercentage.toFixed(1)}%
                </div>
                <div className="text-gray-500">可用性</div>
              </div>
            </div>
          </div>
        </div>
      </nav>
    </aside>
  );
};

export default Sidebar;
