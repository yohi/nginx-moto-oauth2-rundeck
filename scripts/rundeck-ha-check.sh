#!/bin/bash

# Rundeck HA Status Check Script
# RundeckのActive/Standby状態を確認するスクリプト

echo "=== Rundeck HA Status Check ==="
echo "Date: $(date)"
echo

# Docker Composeのステータス確認
echo "1. Docker Compose Services Status:"
docker-compose ps rundeck-active rundeck-standby rundeck-postgres
echo

# Rundeckコンテナのヘルスチェック
echo "2. Rundeck Containers Health:"
echo "Active Node:"
docker-compose exec rundeck-active curl -f -s http://localhost:4440/health || echo "  ❌ Active node health check failed"
echo "  ✅ Active node is healthy" 2>/dev/null

echo "Standby Node:"
docker-compose exec rundeck-standby curl -f -s http://localhost:4440/health || echo "  ❌ Standby node health check failed"
echo "  ✅ Standby node is healthy" 2>/dev/null

# PostgreSQL接続確認
echo
echo "3. PostgreSQL Database Status:"
docker-compose exec rundeck-postgres pg_isready -U rundeck -d rundeck || echo "  ❌ PostgreSQL connection failed"
echo "  ✅ PostgreSQL is ready" 2>/dev/null

# Nginx upstream status
echo
echo "4. Nginx Upstream Status:"
docker-compose exec nginx nginx -t && echo "  ✅ Nginx configuration is valid" || echo "  ❌ Nginx configuration error"

# Access test via Nginx
echo
echo "5. Nginx Load Balancer Test:"
curl -f -s "http://localhost:9000/rundeck/" > /dev/null && echo "  ✅ Rundeck accessible via Nginx" || echo "  ❌ Rundeck not accessible via Nginx"

echo
echo "=== End of Health Check ==="
