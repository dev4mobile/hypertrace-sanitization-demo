#!/bin/bash

# Kafka Topic 管理脚本
# 使用方法: ./kafka-topics.sh [create|list|delete|describe] [topic-name]

KAFKA_CONTAINER="kafka"
KAFKA_BOOTSTRAP_SERVERS="localhost:9092"

function create_topic() {
    local topic_name=$1
    if [ -z "$topic_name" ]; then
        echo "错误: 请提供 topic 名称"
        echo "使用方法: $0 create <topic-name>"
        exit 1
    fi

    echo "创建 topic: $topic_name"
    docker exec $KAFKA_CONTAINER kafka-topics \
        --create \
        --topic $topic_name \
        --bootstrap-server $KAFKA_BOOTSTRAP_SERVERS \
        --partitions 3 \
        --replication-factor 1
}

function list_topics() {
    echo "列出所有 topics:"
    docker exec $KAFKA_CONTAINER kafka-topics \
        --list \
        --bootstrap-server $KAFKA_BOOTSTRAP_SERVERS
}

function describe_topic() {
    local topic_name=$1
    if [ -z "$topic_name" ]; then
        echo "错误: 请提供 topic 名称"
        echo "使用方法: $0 describe <topic-name>"
        exit 1
    fi

    echo "描述 topic: $topic_name"
    docker exec $KAFKA_CONTAINER kafka-topics \
        --describe \
        --topic $topic_name \
        --bootstrap-server $KAFKA_BOOTSTRAP_SERVERS
}

function delete_topic() {
    local topic_name=$1
    if [ -z "$topic_name" ]; then
        echo "错误: 请提供 topic 名称"
        echo "使用方法: $0 delete <topic-name>"
        exit 1
    fi

    echo "删除 topic: $topic_name"
    docker exec $KAFKA_CONTAINER kafka-topics \
        --delete \
        --topic $topic_name \
        --bootstrap-server $KAFKA_BOOTSTRAP_SERVERS
}

function show_usage() {
    echo "Kafka Topic 管理脚本"
    echo "使用方法: $0 [create|list|delete|describe] [topic-name]"
    echo ""
    echo "命令:"
    echo "  create <topic-name>     创建新的 topic"
    echo "  list                    列出所有 topics"
    echo "  describe <topic-name>   描述 topic 详情"
    echo "  delete <topic-name>     删除 topic"
    echo ""
    echo "示例:"
    echo "  $0 create user-events"
    echo "  $0 list"
    echo "  $0 describe user-events"
    echo "  $0 delete user-events"
}

# 主逻辑
case "$1" in
    create)
        create_topic $2
        ;;
    list)
        list_topics
        ;;
    describe)
        describe_topic $2
        ;;
    delete)
        delete_topic $2
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
