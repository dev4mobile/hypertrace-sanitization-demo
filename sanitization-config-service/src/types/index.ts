export type RuleType = 'regex' | 'key_keyword';
export type SeverityLevel = 'low' | 'medium' | 'high' | 'critical';

export type CategoryType = 'personal_info' | 'financial' | 'security' | 'medical' | 'business' | 'other';

// New format condition types
export interface RegexCondition {
  type: 'regex';
  pattern: string;
  description?: string;
}

export interface KeywordCondition {
  type: 'key_keyword';
  keywords: string[];
  caseSensitive?: boolean;
  description?: string;
}

export type RuleCondition = RegexCondition | KeywordCondition;

// New format action types
export interface MaskAction {
  algorithm: 'mask';
  params: {
    maskChar: string;
    prefix: number;
    suffix: number;
    keepDomain?: boolean;
  };
}

export interface HashAction {
  algorithm: 'hash';
  params: {
    type: 'sha256' | 'md5' | 'sha1';
    salt: string;
  };
}

export interface EncryptAction {
  algorithm: 'encrypt';
  params: {
    key: string;
    iv?: string;
  };
}

export interface ReplaceAction {
  algorithm: 'replace';
  params: {
    replacement: string;
  };
}

export interface RemoveAction {
  algorithm: 'remove';
  params: {};
}

export type RuleAction = MaskAction | HashAction | EncryptAction | ReplaceAction | RemoveAction;

export interface SanitizationRule {
  id: string;
  name: string;
  description: string;
  enabled: boolean;
  priority: number;
  category: CategoryType;
  sensitivity: SeverityLevel;
  condition: RuleCondition;
  action: RuleAction;

  // Optional application conditions
  includeServices?: string[];
  excludeServices?: string[];
  conditions?: Record<string, any>;

  metadata: {
    createdAt: string;
    updatedAt: string;
    version: string;
    author: string;
  };

  // Timestamps for convenience
  createdAt?: string;
  updatedAt?: string;
}

// Application conditions (optional)
export interface ServiceConditions {
  includeServices?: string[];
  excludeServices?: string[];
  conditions?: Record<string, any>;
}

export interface SanitizationConfig {
  version?: string;
  timestamp?: number;
  enabled: boolean;
  markersEnabled?: boolean;
  markerFormat?: string;
  rules: SanitizationRule[];
  globalSettings?: Record<string, any>;
}

export interface HealthResponse {
  status: string;
  timestamp: string;
  version: string;
  uptime: number;
  checks: Record<string, string>;
}

export interface MetricsResponse {
  totalRules: number;
  enabledRules: number;
  disabledRules: number;
  rulesByType: Record<string, number>;
  rulesBySeverity: Record<string, number>;
  configVersion?: string;
  lastUpdated?: number;
}

export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
  message?: string;
  timestamp?: number;
}

export interface BatchOperationResponse {
  success: boolean;
  successCount: number;
  failureCount: number;
  failedRules?: string[];
  message: string;
  timestamp?: number;
}

export interface ValidationResponse {
  valid: boolean;
  errors?: string[];
  message?: string;
  timestamp?: number;
  testResult?: {
    input: string;
    matches: string[];
    masked: string;
  } | null;
  testOutput?: string; // For backward compatibility
}
