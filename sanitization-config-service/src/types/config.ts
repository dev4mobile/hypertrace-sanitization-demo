export interface ServerConfig {
  port: number;
  host: string;
  readTimeout: string;
  writeTimeout: string;
  idleTimeout: string;
}

export interface AuthConfig {
  enabled: boolean;
  jwtSecret: string;
  tokenHeader: string;
}

export interface RulesConfigOptions {
  configFile: string;
  reloadEnabled: boolean;
  reloadInterval: string;
}

export interface LoggingConfig {
  level: string;
  format: string;
  pretty?: boolean;
}

export interface Config {
  server: ServerConfig;
  auth: AuthConfig;
  rules: RulesConfigOptions;
  logging: LoggingConfig;
}
