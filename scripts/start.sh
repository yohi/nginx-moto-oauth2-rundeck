#!/bin/bash

# OAuth Docker Compose環境起動スクリプト

set -e

echo "=================================================="
echo "OAuth Docker Compose環境起動スクリプト"
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

# .envファイルの確認
check_env_file() {
    if [ ! -f .env ]; then
        print_error ".envファイルが見つかりません"
        print_info "セットアップスクリプトを実行してください: ./scripts/setup.sh"
        exit 1
    fi
    
    source .env
    
    if [ "$OAUTH2_PROXY_CLIENT_ID" = "your-github-oauth-client-id" ]; then
        print_warning "OAuth Client IDが設定されていません"
        print_warning "正しく動作させるには.envファイルでOAuth設定を行ってください"
    fi
}

# Docker Composeサービスの起動
start_services() {
    print_info "Docker Composeサービスを起動中..."
    
    if command -v docker-compose &> /dev/null; then
        docker-compose up -d
    else
        docker compose up -d
    fi
    
    print_success "すべてのサービスが起動されました"
}

# サービス状態の確認
check_services() {
    print_info "サービス状態を確認中..."
    
    sleep 5
    
    if command -v docker-compose &> /dev/null; then
        docker-compose ps
    else
        docker compose ps
    fi
}

# ヘルスチェック
health_check() {
    print_info "ヘルスチェックを実行中..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        print_info "試行 $attempt/$max_attempts..."
        
        # Nginxのヘルスチェック
        if curl -s -f http://localhost/health > /dev/null 2>&1; then
            print_success "Nginxが正常に動作しています"
            break
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            print_warning "ヘルスチェックが完了しませんでした。手動で確認してください。"
            break
        fi
        
        sleep 5
        ((attempt++))
    done
}

# 接続情報の表示
show_connection_info() {
    echo
    print_success "環境が正常に起動しました！"
    echo
    echo "アクセス情報:"
    echo "  アプリケーション: http://localhost"
    echo "  ヘルスチェック: http://localhost/health"
    echo "  バックエンドAPI: http://localhost (認証後)"
    echo
    echo "サービス個別アクセス（デバッグ用）:"
    echo "  Moto (AWS Mock): http://localhost:5000"
    echo
    echo "ログの確認:"
    if command -v docker-compose &> /dev/null; then
        echo "  $ docker-compose logs -f [service-name]"
    else
        echo "  $ docker compose logs -f [service-name]"
    fi
    echo
    echo "停止方法:"
    echo "  $ ./scripts/stop.sh"
    echo
}

# メイン実行
main() {
    print_info "環境を起動します..."
    
    check_env_file
    start_services
    check_services
    health_check
    show_connection_info
}

main "$@"