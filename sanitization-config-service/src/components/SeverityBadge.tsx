
interface SeverityBadgeProps {
  severity: string;
}

const SeverityBadge = ({ severity }: SeverityBadgeProps) => {
  // 敏感级别中文映射
  const getSeverityText = (severity: string) => {
    const severityMap: Record<string, string> = {
      'CRITICAL': '极高',
      'HIGH': '高',
      'MEDIUM': '中',
      'LOW': '低'
    };
    return severityMap[severity.toUpperCase()] || severity;
  };

  // 现代化的敏感级别样式
  const getSeverityClasses = (severity: string) => {
    switch (severity.toUpperCase()) {
      case 'CRITICAL':
        return 'bg-error-100 text-error-700 border border-error-200';
      case 'HIGH':
        return 'bg-warning-100 text-warning-700 border border-warning-200';
      case 'MEDIUM':
        return 'bg-yellow-100 text-yellow-700 border border-yellow-200';
      case 'LOW':
        return 'bg-success-100 text-success-700 border border-success-200';
      default:
        return 'bg-gray-100 text-gray-700 border border-gray-200';
    }
  };

  return (
    <span
      className={`inline-flex items-center px-2.5 py-0.5 text-xs font-medium rounded-full transition-all duration-200 ${getSeverityClasses(severity)}`}
    >
      {getSeverityText(severity)}
    </span>
  );
};

export default SeverityBadge;
