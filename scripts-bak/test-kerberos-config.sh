#!/bin/bash

# Kerberos 配置测试脚本
# 使用方法: ./scripts/test-kerberos-config.sh

echo "=== Kafka Kerberos 配置测试 ==="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查函数
check_file() {
    local file=$1
    local description=$2
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $description: $file"
        return 0
    else
        echo -e "${RED}✗${NC} $description: $file (不存在)"
        return 1
    fi
}

check_command() {
    local cmd=$1
    local description=$2
    
    if command -v "$cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $description: $cmd"
        return 0
    else
        echo -e "${RED}✗${NC} $description: $cmd (未找到)"
        return 1
    fi
}

echo ""
echo "1. 检查 Kerberos 工具..."
check_command "kinit" "Kerberos 初始化工具"
check_command "klist" "Kerberos 票据列表工具"
check_command "kdestroy" "Kerberos 票据销毁工具"

echo ""
echo "2. 检查配置文件..."
check_file "src/main/resources/kafka_client_jaas.conf" "JAAS 配置文件"
check_file "src/main/resources/krb5.conf" "Kerberos 配置文件"
check_file "src/main/resources/application-kerberos.yml" "Spring Kerberos 配置"

echo ""
echo "3. 检查 Java 文件..."
check_file "src/main/java/com/example/hypertracedemo/config/KafkaConfig.java" "Kafka 配置类"
check_file "src/main/java/com/example/hypertracedemo/service/KerberosConfigService.java" "Kerberos 配置服务"

echo ""
echo "4. 检查脚本文件..."
check_file "scripts/run-with-kerberos.sh" "Kerberos 启动脚本"

# 检查脚本权限
if [ -x "scripts/run-with-kerberos.sh" ]; then
    echo -e "${GREEN}✓${NC} 启动脚本具有执行权限"
else
    echo -e "${YELLOW}!${NC} 启动脚本缺少执行权限，正在修复..."
    chmod +x scripts/run-with-kerberos.sh
    echo -e "${GREEN}✓${NC} 执行权限已添加"
fi

echo ""
echo "5. 检查 Gradle 构建..."
if [ -f "build.gradle.kts" ]; then
    echo -e "${GREEN}✓${NC} Gradle 构建文件存在"
    
    # 检查是否可以构建
    echo "正在测试构建..."
    if ./gradlew compileJava --quiet; then
        echo -e "${GREEN}✓${NC} Java 编译成功"
    else
        echo -e "${RED}✗${NC} Java 编译失败"
    fi
else
    echo -e "${RED}✗${NC} Gradle 构建文件不存在"
fi

echo ""
echo "6. 配置文件内容检查..."

# 检查 JAAS 配置
if [ -f "src/main/resources/kafka_client_jaas.conf" ]; then
    if grep -q "KafkaClient" "src/main/resources/kafka_client_jaas.conf"; then
        echo -e "${GREEN}✓${NC} JAAS 配置包含 KafkaClient 部分"
    else
        echo -e "${YELLOW}!${NC} JAAS 配置可能需要更新 KafkaClient 部分"
    fi
    
    if grep -q "useKeyTab=true" "src/main/resources/kafka_client_jaas.conf"; then
        echo -e "${GREEN}✓${NC} JAAS 配置启用了 keytab 认证"
    else
        echo -e "${YELLOW}!${NC} JAAS 配置可能需要启用 keytab 认证"
    fi
fi

# 检查 KRB5 配置
if [ -f "src/main/resources/krb5.conf" ]; then
    if grep -q "\[libdefaults\]" "src/main/resources/krb5.conf"; then
        echo -e "${GREEN}✓${NC} KRB5 配置包含 libdefaults 部分"
    else
        echo -e "${YELLOW}!${NC} KRB5 配置可能需要 libdefaults 部分"
    fi
    
    if grep -q "\[realms\]" "src/main/resources/krb5.conf"; then
        echo -e "${GREEN}✓${NC} KRB5 配置包含 realms 部分"
    else
        echo -e "${YELLOW}!${NC} KRB5 配置可能需要 realms 部分"
    fi
fi

echo ""
echo "7. 使用说明..."
echo -e "${YELLOW}配置步骤:${NC}"
echo "1. 更新 src/main/resources/krb5.conf 中的 realm 和 KDC 信息"
echo "2. 更新 src/main/resources/kafka_client_jaas.conf 中的 principal 和 keytab 路径"
echo "3. 更新 src/main/resources/application-kerberos.yml 中的 Kerberos 配置"
echo "4. 确保 keytab 文件存在且权限正确 (600)"
echo "5. 运行: ./scripts/run-with-kerberos.sh"

echo ""
echo -e "${YELLOW}调试选项:${NC}"
echo "启用调试: DEBUG=true ./scripts/run-with-kerberos.sh"
echo "查看 Kerberos 票据: klist"
echo "测试认证: kinit your-principal@YOUR-REALM.COM"

echo ""
echo "=== 配置检查完成 ==="
