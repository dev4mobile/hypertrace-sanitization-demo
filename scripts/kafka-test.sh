#!/bin/bash

# Kafka Producer/Consumer 测试脚本
# 使用方法: ./kafka-test.sh [producer|consumer] [topic-name]

KAFKA_CONTAINER="kafka"
KAFKA_BOOTSTRAP_SERVERS="localhost:9092"
DEFAULT_TOPIC="test-topic"

function start_producer() {
    local topic_name=${1:-$DEFAULT_TOPIC}

    echo "启动 Kafka Producer for topic: $topic_name"
    echo "请输入消息 (按 Ctrl+C 退出):"
    echo "-----------------------------------"

    docker exec -it $KAFKA_CONTAINER kafka-console-producer \
        --topic $topic_name \
        --bootstrap-server $KAFKA_BOOTSTRAP_SERVERS
}

function start_consumer() {
    local topic_name=${1:-$DEFAULT_TOPIC}

    echo "启动 Kafka Consumer for topic: $topic_name"
    echo "等待消息... (按 Ctrl+C 退出)"
    echo "-----------------------------------"

    docker exec -it $KAFKA_CONTAINER kafka-console-consumer \
        --topic $topic_name \
        --bootstrap-server $KAFKA_BOOTSTRAP_SERVERS \
        --from-beginning
}

function send_test_messages() {
    local topic_name=${1:-$DEFAULT_TOPIC}

    echo "发送测试消息到 topic: $topic_name"

    # 创建测试消息
    test_messages=(
        '{"id": 1, "message": "Hello Kafka!", "timestamp": "'$(date -Iseconds)'"}'
        '{"id": 2, "message": "This is a test message", "timestamp": "'$(date -Iseconds)'"}'
        '{"id": 3, "message": "Kafka with Hypertrace monitoring", "timestamp": "'$(date -Iseconds)'"}'
    )

    for msg in "${test_messages[@]}"; do
        echo "发送: $msg"
        echo "$msg" | docker exec -i $KAFKA_CONTAINER kafka-console-producer \
            --topic $topic_name \
            --bootstrap-server $KAFKA_BOOTSTRAP_SERVERS
        sleep 1
    done

    echo "测试消息发送完成！"
}

function show_consumer_groups() {
    echo "列出所有 Consumer Groups:"
    docker exec $KAFKA_CONTAINER kafka-consumer-groups \
        --bootstrap-server $KAFKA_BOOTSTRAP_SERVERS \
        --list
}

function describe_consumer_group() {
    local group_name=$1
    if [ -z "$group_name" ]; then
        echo "错误: 请提供 consumer group 名称"
        echo "使用方法: $0 describe-group <group-name>"
        exit 1
    fi

    echo "描述 Consumer Group: $group_name"
    docker exec $KAFKA_CONTAINER kafka-consumer-groups \
        --bootstrap-server $KAFKA_BOOTSTRAP_SERVERS \
        --group $group_name \
        --describe
}

function show_usage() {
    echo "Kafka Producer/Consumer 测试脚本"
    echo "使用方法: $0 [command] [topic-name]"
    echo ""
    echo "命令:"
    echo "  producer [topic-name]           启动交互式 producer"
    echo "  consumer [topic-name]           启动 consumer"
    echo "  test-messages [topic-name]      发送测试消息"
    echo "  groups                          列出所有 consumer groups"
    echo "  describe-group <group-name>     描述 consumer group"
    echo ""
    echo "示例:"
    echo "  $0 producer user-events"
    echo "  $0 consumer user-events"
    echo "  $0 test-messages user-events"
    echo "  $0 groups"
    echo ""
    echo "注意: 如果不指定 topic-name，将使用默认 topic: $DEFAULT_TOPIC"
}

# 检查 Kafka 容器是否运行
function check_kafka_running() {
    if ! docker ps | grep -q $KAFKA_CONTAINER; then
        echo "错误: Kafka 容器未运行！"
        echo "请先启动 Kafka: docker-compose up -d kafka"
        exit 1
    fi
}

# 主逻辑
check_kafka_running

case "$1" in
    producer)
        start_producer $2
        ;;
    consumer)
        start_consumer $2
        ;;
    test-messages)
        send_test_messages $2
        ;;
    groups)
        show_consumer_groups
        ;;
    describe-group)
        describe_consumer_group $2
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
