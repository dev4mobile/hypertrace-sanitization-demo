#!/bin/bash

# Kerberos KDC 初始化脚本 - 简化版本

set -e

echo "=== 初始化 Kerberos KDC ==="

# 设置环境变量
export KRB5_REALM=${KRB5_REALM:-EXAMPLE.COM}
export KRB5_KDC=${KRB5_KDC:-kdc.example.com}
export KRB5_PASS=${KRB5_PASS:-admin123}
export DEBIAN_FRONTEND=noninteractive

echo "Realm: $KRB5_REALM"
echo "KDC: $KRB5_KDC"

# 安装 Kerberos 软件包
echo "安装 Kerberos 软件包..."
apt-get update -qq
apt-get install -y krb5-kdc krb5-admin-server krb5-config krb5-user

# 创建必要的目录
mkdir -p /var/lib/krb5kdc
mkdir -p /etc/krb5kdc
mkdir -p /var/log
mkdir -p /var/kerberos

# 创建 krb5.conf 文件
echo "创建 krb5.conf 配置文件..."
cat > /etc/krb5.conf << EOF
[libdefaults]
    default_realm = $KRB5_REALM
    dns_lookup_realm = false
    dns_lookup_kdc = false
    ticket_lifetime = 24h
    renew_lifetime = 7d
    forwardable = true
    default_tgs_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96
    default_tkt_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96
    permitted_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96

[realms]
    $KRB5_REALM = {
        kdc = $KRB5_KDC:88
        admin_server = $KRB5_KDC:749
        default_domain = example.com
    }

[domain_realm]
    .example.com = $KRB5_REALM
    example.com = $KRB5_REALM
    .kafka.example.com = $KRB5_REALM
    kafka.example.com = $KRB5_REALM

[logging]
    default = FILE:/var/log/krb5libs.log
    kdc = FILE:/var/log/krb5kdc.log
    admin_server = FILE:/var/log/kadmind.log
EOF

# 创建 KDC 配置文件
echo "创建 KDC 配置文件..."
cat > /etc/krb5kdc/kdc.conf << EOF
[kdcdefaults]
    kdc_ports = 88
    kdc_tcp_ports = 88

[realms]
    $KRB5_REALM = {
        acl_file = /etc/krb5kdc/kadm5.acl
        dict_file = /usr/share/dict/words
        admin_keytab = /etc/krb5kdc/kadm5.keytab
        database_name = /var/lib/krb5kdc/principal
        key_stash_file = /var/lib/krb5kdc/.k5.$KRB5_REALM
        supported_enctypes = aes256-cts:normal aes128-cts:normal
        max_life = 12h 0m 0s
        max_renewable_life = 7d 0h 0m 0s
        default_principal_flags = +preauth
    }

[logging]
    kdc = FILE:/var/log/krb5kdc.log
    admin_server = FILE:/var/log/kadmind.log
EOF

# 创建 ACL 文件
echo "创建 ACL 文件..."
cat > /etc/krb5kdc/kadm5.acl << EOF
*/admin@$KRB5_REALM *
admin@$KRB5_REALM *
kafka/kafka.example.com@$KRB5_REALM *
kafka-client@$KRB5_REALM *
EOF

# 初始化 KDC 数据库
echo "初始化 KDC 数据库..."
if [ ! -f /var/lib/krb5kdc/principal ]; then
    echo -e "$KRB5_PASS\n$KRB5_PASS" | kdb5_util create -s -r $KRB5_REALM
fi

echo "启动 KDC 服务..."
krb5kdc -n &
KDC_PID=$!

sleep 3

echo "启动 kadmin 服务..."
kadmind -nofork &
KADMIN_PID=$!

sleep 5

# 创建主体
echo "创建 Kerberos 主体..."

# 创建管理员主体
echo -e "$KRB5_PASS\n$KRB5_PASS" | kadmin.local -q "addprinc admin@$KRB5_REALM" || echo "admin principal may already exist"

# 创建 Kafka 服务主体
kadmin.local -q "addprinc -randkey kafka/kafka.example.com@$KRB5_REALM" || echo "kafka service principal may already exist"

# 创建 Kafka 客户端主体
kadmin.local -q "addprinc -randkey kafka-client@$KRB5_REALM" || echo "kafka-client principal may already exist"

# 创建 keytab 文件
echo "创建 keytab 文件..."
kadmin.local -q "ktadd -k /var/kerberos/kafka.keytab kafka/kafka.example.com@$KRB5_REALM"
kadmin.local -q "ktadd -k /var/kerberos/kafka-client.keytab kafka-client@$KRB5_REALM"

# 设置权限
chmod 644 /var/kerberos/kafka.keytab
chmod 644 /var/kerberos/kafka-client.keytab

echo "=== Kerberos KDC 初始化完成 ==="

# 显示状态
echo "已创建的主体:"
kadmin.local -q "listprincs"

echo "Kafka 服务 keytab:"
klist -kt /var/kerberos/kafka.keytab

echo "Kafka 客户端 keytab:"
klist -kt /var/kerberos/kafka-client.keytab

echo "KDC 服务正在运行..."
echo "KDC PID: $KDC_PID"
echo "KADMIN PID: $KADMIN_PID"

# 等待信号并保持运行
trap "echo 'Stopping services...'; kill $KDC_PID $KADMIN_PID 2>/dev/null; exit 0" SIGTERM SIGINT

# 保持脚本运行并监控服务
while true; do
    sleep 60
    if ! kill -0 $KDC_PID 2>/dev/null; then
        echo "KDC 服务已停止，重新启动..."
        krb5kdc -n &
        KDC_PID=$!
    fi

    if ! kill -0 $KADMIN_PID 2>/dev/null; then
        echo "KADMIN 服务已停止，重新启动..."
        kadmind -nofork &
        KADMIN_PID=$!
    fi
done
