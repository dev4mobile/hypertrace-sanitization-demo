#!/bin/bash

# 下载 JMX Prometheus Java Agent 及 Kafka JMX 配置
JMX_AGENT_VERSION="0.20.0"
JMX_AGENT_JAR="jmx_prometheus_javaagent-${JMX_AGENT_VERSION}.jar"
JMX_AGENT_URL="https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/${JMX_AGENT_VERSION}/${JMX_AGENT_JAR}"
JMX_CONFIG_FILE="kafka-2_0_0.yml"
TARGET_DIR="agents"

set -e

mkdir -p $TARGET_DIR
cd $TARGET_DIR

# 下载 JAR
if [ ! -f "$JMX_AGENT_JAR" ]; then
  echo "下载 $JMX_AGENT_JAR ..."
  curl -LO $JMX_AGENT_URL
else
  echo "$JMX_AGENT_JAR 已存在，跳过下载。"
fi

# 生成 Kafka JMX 配置
if [ ! -f "$JMX_CONFIG_FILE" ]; then
  echo "生成 $JMX_CONFIG_FILE ..."
  cat > $JMX_CONFIG_FILE <<EOF
---
startDelaySeconds: 0
jmxUrl: ""
jmxUsername: ""
jmxPassword: ""
lowercaseOutputName: true
lowercaseOutputLabelNames: true
rules:
  - pattern: 'kafka.server<type=(.+), name=(.+)><>Value'
    name: kafka_server_$1_$2
    type: GAUGE
    labels:
      type: "$1"
      name: "$2"
  - pattern: 'kafka.network<type=RequestMetrics, name=(.+), request=(.+)><>Count'
    name: kafka_network_requestmetrics_$1_count
    type: COUNTER
    labels:
      name: "$1"
      request: "$2"
  - pattern: 'kafka.controller<type=(.+), name=(.+)><>Value'
    name: kafka_controller_$1_$2
    type: GAUGE
    labels:
      type: "$1"
      name: "$2"
EOF
else
  echo "$JMX_CONFIG_FILE 已存在，跳过生成。"
fi

echo "JMX Prometheus Java Agent 和配置已准备好。"
