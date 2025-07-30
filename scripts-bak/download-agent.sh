#!/bin/bash

# 下载 Hypertrace Java Agent
echo "正在下载 Hypertrace Java Agent..."

# 创建 agents 目录
mkdir -p agents

# 从 GitHub API 获取最新版本号
# 增加重试和超时机制
LATEST_VERSION_URL="https://api.github.com/repos/hypertrace/javaagent/releases/latest"
AGENT_VERSION=$(curl -s --retry 3 --retry-delay 5 -L $LATEST_VERSION_URL | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/v//')

if [ -z "$AGENT_VERSION" ]; then
    echo "无法获取最新版本，使用默认版本 1.3.24"
    AGENT_VERSION="1.3.24"
fi

echo "最新版本: $AGENT_VERSION"
AGENT_JAR="hypertrace-agent-${AGENT_VERSION}-all.jar"
AGENT_DOWNLOAD_URL="https://github.com/hypertrace/javaagent/releases/download/v${AGENT_VERSION}/hypertrace-agent-${AGENT_VERSION}-all.jar"
TARGET_DIR="agents"

# 下载 JAR
if [ ! -f "$AGENT_JAR" ]; then
  echo "正在从 $AGENT_DOWNLOAD_URL 下载..."
  # 强制使用 IPv4，增加超时和重试
  curl -L -4 --retry 3 --retry-delay 5 --connect-timeout 20 -o "$AGENT_JAR" "$AGENT_DOWNLOAD_URL"
  if [ $? -ne 0 ]; then
      echo "下载失败，请检查网络连接或手动下载"
      exit 1
  fi
  echo "下载成功！"
else
    echo "Hypertrace Java Agent 下载成功: agents/hypertrace-agent-${LATEST_VERSION}-all.jar"

    # 创建符号链接
    ln -sf "hypertrace-agent-${LATEST_VERSION}-all.jar" "agents/hypertrace-agent.jar"
    echo "创建符号链接: agents/hypertrace-agent.jar"
fi
