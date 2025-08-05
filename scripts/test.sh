#!/bin/bash

# OAuth Docker Compose環境テストスクリプト

set -e

echo "=================================================="
echo "OAuth Docker Compose環境テストスクリプト"
echo "=================================================="

# 色付きの出力関数
print_info() {
    echo -e "\033[34m[INFO]\033[0m $1"
}

print_success() {
    echo -e "\033[32m[SUCCESS]\033[0m $1"
}

print_warning() {
    echo -e "\033[33m[WARNING]\033[0m $1"
}

print_error() {
    echo -e "\033[31m[ERROR]\033[0m $1"
}

# テスト結果の集計
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# テスト結果を記録する関数
record_test() {
    local test_name="$1"
    local result="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [ "$result" = "PASS" ]; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
        print_success "✓ $test_name"
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
        print_error "✗ $test_name"
    fi
}

# サービス起動状態のテスト
test_services_running() {
    print_info "サービス起動状態のテスト中..."
    
    local services=("nginx" "oauth2-proxy" "moto" "backend")
    
    for service in "${services[@]}"; do
        if command -v docker-compose &> /dev/null; then
            if docker-compose ps | grep -q "$service.*Up"; then
                record_test "$service サービス起動確認" "PASS"
            else
                record_test "$service サービス起動確認" "FAIL"
            fi
        else
            if docker compose ps | grep -q "$service.*running"; then
                record_test "$service サービス起動確認" "PASS"
            else
                record_test "$service サービス起動確認" "FAIL"
            fi
        fi
    done
}

# ヘルスチェックエンドポイントのテスト
test_health_endpoints() {
    print_info "ヘルスチェックエンドポイントのテスト中..."
    
    # Nginxヘルスチェック
    if curl -s -f http://localhost/health > /dev/null 2>&1; then
        record_test "Nginx ヘルスチェック" "PASS"
    else
        record_test "Nginx ヘルスチェック" "FAIL"
    fi
    
    # OAuth2Proxy ping（認証不要）
    if curl -s -f http://localhost:4180/ping > /dev/null 2>&1; then
        record_test "OAuth2Proxy ping" "PASS"
    else
        record_test "OAuth2Proxy ping" "FAIL"
    fi
    
    # Moto直接アクセス
    if curl -s -f http://localhost:5000/ > /dev/null 2>&1; then
        record_test "Moto エンドポイント" "PASS"
    else
        record_test "Moto エンドポイント" "FAIL"
    fi
}

# OAuth認証リダイレクトのテスト
test_oauth_redirect() {
    print_info "OAuth認証リダイレクトのテスト中..."
    
    # メインページへのアクセスでリダイレクトが発生することを確認
    local response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/)
    
    if [ "$response" = "302" ] || [ "$response" = "200" ]; then
        record_test "OAuth リダイレクト動作" "PASS"
    else
        record_test "OAuth リダイレクト動作" "FAIL"
    fi
}

# ネットワーク接続のテスト
test_network_connectivity() {
    print_info "サービス間ネットワーク接続のテスト中..."
    
    # Backend → Moto接続テスト
    if command -v docker-compose &> /dev/null; then
        if docker-compose exec -T backend curl -s -f http://moto:5000/ > /dev/null 2>&1; then
            record_test "Backend → Moto 接続" "PASS"
        else
            record_test "Backend → Moto 接続" "FAIL"
        fi
        
        # Nginx → Backend接続テスト
        if docker-compose exec -T nginx curl -s -f http://backend:8080/health > /dev/null 2>&1; then
            record_test "Nginx → Backend 接続" "PASS"
        else
            record_test "Nginx → Backend 接続" "FAIL"
        fi
        
        # Nginx → OAuth2Proxy接続テスト
        if docker-compose exec -T nginx curl -s -f http://oauth2-proxy:4180/ping > /dev/null 2>&1; then
            record_test "Nginx → OAuth2Proxy 接続" "PASS"
        else
            record_test "Nginx → OAuth2Proxy 接続" "FAIL"
        fi
    else
        if docker compose exec -T backend curl -s -f http://moto:5000/ > /dev/null 2>&1; then
            record_test "Backend → Moto 接続" "PASS"
        else
            record_test "Backend → Moto 接続" "FAIL"
        fi
        
        if docker compose exec -T nginx curl -s -f http://backend:8080/health > /dev/null 2>&1; then
            record_test "Nginx → Backend 接続" "PASS"
        else
            record_test "Nginx → Backend 接続" "FAIL"
        fi
        
        if docker compose exec -T nginx curl -s -f http://oauth2-proxy:4180/ping > /dev/null 2>&1; then
            record_test "Nginx → OAuth2Proxy 接続" "PASS"
        else
            record_test "Nginx → OAuth2Proxy 接続" "FAIL"
        fi
    fi
}

# 設定ファイルの検証
test_configuration() {
    print_info "設定ファイルの検証中..."
    
    # .env ファイルの存在確認
    if [ -f .env ]; then
        record_test ".env ファイル存在確認" "PASS"
        
        # 必要な環境変数の確認
        source .env
        
        if [ -n "$OAUTH2_PROXY_CLIENT_ID" ]; then
            record_test "OAUTH2_PROXY_CLIENT_ID 設定確認" "PASS"
        else
            record_test "OAUTH2_PROXY_CLIENT_ID 設定確認" "FAIL"
        fi
        
        if [ -n "$OAUTH2_PROXY_CLIENT_SECRET" ]; then
            record_test "OAUTH2_PROXY_CLIENT_SECRET 設定確認" "PASS"
        else
            record_test "OAUTH2_PROXY_CLIENT_SECRET 設定確認" "FAIL"
        fi
        
        if [ -n "$OAUTH2_PROXY_COOKIE_SECRET" ]; then
            record_test "OAUTH2_PROXY_COOKIE_SECRET 設定確認" "PASS"
        else
            record_test "OAUTH2_PROXY_COOKIE_SECRET 設定確認" "FAIL"
        fi
    else
        record_test ".env ファイル存在確認" "FAIL"
    fi
    
    # Nginx設定ファイルの確認
    if [ -f nginx/nginx.conf ]; then
        record_test "Nginx 設定ファイル存在確認" "PASS"
    else
        record_test "Nginx 設定ファイル存在確認" "FAIL"
    fi
    
    # Docker Compose設定ファイルの確認
    if [ -f docker-compose.yml ]; then
        record_test "Docker Compose 設定ファイル存在確認" "PASS"
    else
        record_test "Docker Compose 設定ファイル存在確認" "FAIL"
    fi
}

# Moto AWS サービステスト
test_moto_aws_services() {
    print_info "Moto AWS サービステスト中..."
    
    # S3サービステスト
    if curl -s -f "http://localhost:5000/?Action=ListBuckets&Version=2006-03-01" > /dev/null 2>&1; then
        record_test "Moto S3 サービス" "PASS"
    else
        record_test "Moto S3 サービス" "FAIL"
    fi
    
    # DynamoDBサービステスト（簡易）
    if curl -s -f -X POST "http://localhost:5000/" \
        -H "Content-Type: application/x-amz-json-1.0" \
        -H "X-Amz-Target: DynamoDB_20120810.ListTables" \
        -d '{}' > /dev/null 2>&1; then
        record_test "Moto DynamoDB サービス" "PASS"
    else
        record_test "Moto DynamoDB サービス" "FAIL"
    fi
}

# パフォーマンステスト（簡易）
test_performance() {
    print_info "パフォーマンステスト中..."
    
    # レスポンス時間テスト（5秒以内）
    local start_time=$(date +%s)
    curl -s -f http://localhost/health > /dev/null 2>&1
    local end_time=$(date +%s)
    local response_time=$((end_time - start_time))
    
    if [ $response_time -le 5 ]; then
        record_test "レスポンス時間（5秒以内）" "PASS"
    else
        record_test "レスポンス時間（5秒以内）" "FAIL"
    fi
}

# 総合レポートの出力
print_test_summary() {
    echo
    echo "=================================================="
    echo "テスト結果サマリー"
    echo "=================================================="
    echo "総テスト数: $TOTAL_TESTS"
    echo "成功: $PASSED_TESTS"
    echo "失敗: $FAILED_TESTS"
    echo
    
    if [ $FAILED_TESTS -eq 0 ]; then
        print_success "すべてのテストが成功しました！"
        echo "OAuth環境は正常に動作しています。"
    else
        print_warning "$FAILED_TESTS 個のテストが失敗しました。"
        echo "ログを確認して問題を解決してください："
        echo "  $ docker-compose logs"
    fi
    
    echo
    echo "テスト完了時刻: $(date)"
    echo "=================================================="
}

# メイン実行
main() {
    print_info "統合テストを開始します..."
    echo
    
    test_configuration
    test_services_running
    test_health_endpoints
    test_oauth_redirect
    test_network_connectivity
    test_moto_aws_services
    test_performance
    
    print_test_summary
    
    if [ $FAILED_TESTS -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

main "$@"