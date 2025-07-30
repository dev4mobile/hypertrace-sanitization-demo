# Java Agent 集成示例

本文档展示如何在 Java Agent 中使用新的 `/api/sanitization/rules` 接口来获取动态脱敏规则。

## 配置管理器更新

更新 `DynamicSanitizationRuleManager` 来使用新的 API 接口：

```java
package org.hypertrace.agent.filter.config;

import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.net.URI;
import java.util.List;
import java.util.concurrent.CompletableFuture;
import java.time.Duration;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.core.type.TypeReference;

public class DynamicSanitizationRuleManager {

  private static final String DEFAULT_API_URL = "http://localhost:3001/api/sanitization/rules";
  private final String apiUrl;
  private final HttpClient httpClient;
  private final ObjectMapper objectMapper;

  public DynamicSanitizationRuleManager() {
    this.apiUrl = System.getProperty("sanitization.rules.api.url", DEFAULT_API_URL);
    this.httpClient = HttpClient.newBuilder()
        .connectTimeout(Duration.ofSeconds(10))
        .build();
    this.objectMapper = new ObjectMapper();
  }

  /**
   * 异步获取启用的脱敏规则
   */
  public CompletableFuture<SanitizationConfig> fetchEnabledRulesAsync() {
    return fetchRulesAsync("enabled=true");
  }

  /**
   * 异步获取指定类别的脱敏规则
   */
  public CompletableFuture<SanitizationConfig> fetchRulesByCategoryAsync(String category) {
    return fetchRulesAsync("category=" + category + "&enabled=true");
  }

  /**
   * 异步获取指定严重级别的脱敏规则
   */
  public CompletableFuture<SanitizationConfig> fetchRulesBySeverityAsync(String severity) {
    return fetchRulesAsync("severity=" + severity + "&enabled=true");
  }

  /**
   * 通用的异步规则获取方法
   */
  private CompletableFuture<SanitizationConfig> fetchRulesAsync(String queryParams) {
    String url = apiUrl + (queryParams.isEmpty() ? "" : "?" + queryParams);

    HttpRequest request = HttpRequest.newBuilder()
        .uri(URI.create(url))
        .header("Accept", "application/json")
        .timeout(Duration.ofSeconds(30))
        .GET()
        .build();

    return httpClient.sendAsync(request, HttpResponse.BodyHandlers.ofString())
        .thenApply(this::parseResponse)
        .exceptionally(this::handleException);
  }

  /**
   * 解析 API 响应
   */
  private SanitizationConfig parseResponse(HttpResponse<String> response) {
    try {
      if (response.statusCode() != 200) {
        throw new RuntimeException("API 请求失败: " + response.statusCode());
      }

      // 解析 API 响应格式
      ApiResponse apiResponse = objectMapper.readValue(response.body(), ApiResponse.class);

      if (!apiResponse.success) {
        throw new RuntimeException("API 返回失败: " + apiResponse.error);
      }

      // 创建脱敏配置对象
      SanitizationConfig config = new SanitizationConfig();
      config.setEnabled(true);
      config.setRules(apiResponse.data.rules);
      config.setVersion("1.0.0");
      config.setTimestamp(apiResponse.timestamp);

      return config;

    } catch (Exception e) {
      throw new RuntimeException("解析规则响应失败", e);
    }
  }

  /**
   * 异常处理
   */
  private SanitizationConfig handleException(Throwable throwable) {
    System.err.println("获取脱敏规则失败: " + throwable.getMessage());

    // 返回默认配置或缓存的配置
    return getDefaultConfig();
  }

  /**
   * 获取默认配置
   */
  private SanitizationConfig getDefaultConfig() {
    SanitizationConfig config = new SanitizationConfig();
    config.setEnabled(false); // 在无法获取规则时禁用脱敏
    config.setRules(List.of());
    return config;
  }

  // API 响应数据结构
  private static class ApiResponse {
    public boolean success;
    public String error;
    public ApiData data;
    public long timestamp;
  }

  private static class ApiData {
    public List<SanitizationRule> rules;
    public Pagination pagination;
  }

  private static class Pagination {
    public int total;
    public int offset;
    public int limit;
    public boolean hasMore;
  }
}
```

## 使用示例

### 1. 在应用启动时获取规则

```java
public class SanitizationService {

  private final DynamicSanitizationRuleManager ruleManager;
  private SanitizationConfig currentConfig;

  public SanitizationService() {
    this.ruleManager = new DynamicSanitizationRuleManager();
    loadInitialRules();
  }

  private void loadInitialRules() {
    // 异步加载启用的规则
    ruleManager.fetchEnabledRulesAsync()
        .thenAccept(config -> {
          this.currentConfig = config;
          System.out.println("已加载 " + config.getRules().size() + " 条脱敏规则");
        })
        .exceptionally(throwable -> {
          System.err.println("初始化脱敏规则失败: " + throwable.getMessage());
          return null;
        });
  }
}
```

### 2. 定期刷新规则

```java
public class RuleRefreshScheduler {

  private final DynamicSanitizationRuleManager ruleManager;
  private final ScheduledExecutorService scheduler;

  public RuleRefreshScheduler(DynamicSanitizationRuleManager ruleManager) {
    this.ruleManager = ruleManager;
    this.scheduler = Executors.newScheduledThreadPool(1);
  }

  public void startPeriodicRefresh() {
    // 每5分钟刷新一次规则
    scheduler.scheduleAtFixedRate(this::refreshRules, 0, 5, TimeUnit.MINUTES);
  }

  private void refreshRules() {
    ruleManager.fetchEnabledRulesAsync()
        .thenAccept(config -> {
          // 更新全局配置
          DynamicSanitizationRuleManager.getInstance().updateConfig(config);
          System.out.println("规则已刷新，当前规则数量: " + config.getRules().size());
        })
        .exceptionally(throwable -> {
          System.err.println("刷新规则失败: " + throwable.getMessage());
          return null;
        });
  }
}
```

### 3. 根据内容类型获取规则

```java
public class ContentTypeBasedSanitization {

  private final DynamicSanitizationRuleManager ruleManager;

  public String sanitizeByContentType(String content, String contentType) {
    // 根据内容类型确定规则类别
    String category = determineCategory(contentType);

    // 获取特定类别的规则
    return ruleManager.fetchRulesByCategoryAsync(category)
        .thenApply(config -> applySanitization(content, config))
        .exceptionally(throwable -> content) // 失败时返回原内容
        .join(); // 同步等待结果
  }

  private String determineCategory(String contentType) {
    if (contentType.contains("json") || contentType.contains("xml")) {
      return "personal_info"; // 结构化数据主要关注个人信息
    } else if (contentType.contains("form")) {
      return "financial"; // 表单数据可能包含金融信息
    }
    return "personal_info"; // 默认类别
  }
}
```

## 配置参数

可以通过系统属性配置 API 服务：

```bash
# 设置脱敏规则 API 地址
-Dsanitization.rules.api.url=http://sanitization-service:3001/api/sanitization/rules

# 设置连接超时时间（毫秒）
-Dsanitization.rules.api.timeout=30000

# 设置规则刷新间隔（分钟）
-Dsanitization.rules.refresh.interval=5
```

## Docker Compose 集成

在 `docker-compose.yml` 中配置 Java Agent 连接到脱敏服务：

```yaml
version: '3.8'
services:
  sanitization-service:
    # ... 脱敏配置服务
    ports:
      - "3001:3001"
    networks:
      - app-network

  your-java-app:
    image: your-app:latest
    environment:
      - JAVA_OPTS=-javaagent:agent.jar -Dsanitization.rules.api.url=http://sanitization-service:3001/api/sanitization/rules
    depends_on:
      - sanitization-service
    networks:
      - app-network

networks:
  app-network:
    driver: bridge
```

## 性能优化建议

1. **缓存规则**: 在本地缓存规则，避免每次请求都调用 API
2. **异步加载**: 使用异步方式加载规则，避免阻塞主线程
3. **失败降级**: 在 API 不可用时使用默认规则或缓存的规则
4. **批量获取**: 一次性获取所有需要的规则，减少 API 调用次数
5. **分页处理**: 对于大量规则，使用分页参数分批获取

## 错误处理

确保在各种异常情况下系统仍能正常工作：

- API 服务不可用
- 网络连接问题
- JSON 解析错误
- 规则格式不正确

在这些情况下，建议回退到默认的脱敏策略或使用缓存的规则。
