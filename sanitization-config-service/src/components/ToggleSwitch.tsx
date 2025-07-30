
interface ToggleSwitchProps {
  enabled: boolean;
  onChange: (enabled: boolean) => void;
  disabled?: boolean;
}

const ToggleSwitch = ({ enabled, onChange, disabled = false }: ToggleSwitchProps) => {
  const handleClick = () => {
    if (!disabled) {
      onChange(!enabled);
    }
  };

  return (
    <button
      onClick={handleClick}
      disabled={disabled}
      className={`relative inline-flex items-center h-6 w-11 flex-shrink-0 rounded-full border-2 border-transparent transition-all duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-primary-500 focus:ring-offset-2 ${
        disabled 
          ? 'cursor-not-allowed opacity-50' 
          : 'cursor-pointer hover:shadow-sm'
      } ${
        enabled 
          ? disabled 
            ? 'bg-primary-400' 
            : 'bg-primary-600 hover:bg-primary-700'
          : disabled 
            ? 'bg-gray-100' 
            : 'bg-gray-200 hover:bg-gray-300'
      }`}
      title={disabled ? '操作中...' : enabled ? '点击禁用' : '点击启用'}
    >
      <span
        aria-hidden="true"
        className={`inline-block h-5 w-5 transform rounded-full bg-white shadow-sm ring-0 transition-all duration-200 ease-in-out ${
          enabled ? 'translate-x-5' : 'translate-x-0'
        }`}
      />
    </button>
  );
};

export default ToggleSwitch;
