#!/bin/bash

# Rundeck Manual Failover Script
# ActiveからStandbyへ手動でフェイルオーバーするスクリプト

NGINX_CONTAINER="oauth-docker-compose-nginx-1"

usage() {
    echo "Usage: $0 [active-to-standby|standby-to-active|status]"
    echo "  active-to-standby  : Activeノードを停止してStandbyに切り替え"
    echo "  standby-to-active  : Standbyノードを停止してActiveに切り替え"
    echo "  status            : 現在のステータスを表示"
    exit 1
}

check_status() {
    echo "=== Current Rundeck HA Status ==="
    echo "Active Node Status:"
    if docker-compose ps rundeck-active | grep -q "Up"; then
        echo "  ✅ rundeck-active: Running"
    else
        echo "  ❌ rundeck-active: Stopped"
    fi

    echo "Standby Node Status:"
    if docker-compose ps rundeck-standby | grep -q "Up"; then
        echo "  ✅ rundeck-standby: Running"
    else
        echo "  ❌ rundeck-standby: Stopped"
    fi

    echo
    echo "Nginx Upstream Configuration:"
    docker-compose exec nginx cat /etc/nginx/nginx.conf | grep -A 6 "upstream rundeck"
}

failover_to_standby() {
    echo "=== Failover: Active -> Standby ==="
    echo "1. Checking current status..."
    check_status

    echo
    echo "2. Stopping Active node..."
    docker-compose stop rundeck-active

    echo "3. Waiting for Nginx to detect failure..."
    sleep 10

    echo "4. Testing Standby accessibility..."
    if curl -f -s "http://localhost:9000/rundeck/" > /dev/null; then
        echo "  ✅ Failover successful - Standby is now handling requests"
    else
        echo "  ❌ Failover failed - Standby not accessible"
        echo "  Attempting to restart Active node..."
        docker-compose start rundeck-active
    fi

    check_status
}

failover_to_active() {
    echo "=== Failover: Standby -> Active ==="
    echo "1. Checking current status..."
    check_status

    echo
    echo "2. Starting Active node..."
    docker-compose start rundeck-active

    echo "3. Waiting for Active node to be ready..."
    sleep 30

    echo "4. Stopping Standby node..."
    docker-compose stop rundeck-standby

    echo "5. Testing Active accessibility..."
    if curl -f -s "http://localhost:9000/rundeck/" > /dev/null; then
        echo "  ✅ Failover successful - Active is now handling requests"
    else
        echo "  ❌ Failover failed - Active not accessible"
        echo "  Attempting to restart Standby node..."
        docker-compose start rundeck-standby
    fi

    check_status
}

case "$1" in
    "active-to-standby")
        failover_to_standby
        ;;
    "standby-to-active")
        failover_to_active
        ;;
    "status")
        check_status
        ;;
    *)
        usage
        ;;
esac
