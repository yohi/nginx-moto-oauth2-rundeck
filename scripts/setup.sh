#!/bin/bash

# OAuth Docker Compose環境セットアップスクリプト

set -e

echo "=================================================="
echo "OAuth Docker Compose環境セットアップスクリプト"
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

# 必要なコマンドの確認
check_requirements() {
    print_info "必要なコマンドの確認中..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Dockerがインストールされていません"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_error "Docker Composeがインストールされていません"
        exit 1
    fi
    
    print_success "必要なコマンドが確認されました"
}

# .envファイルの作成
create_env_file() {
    if [ ! -f .env ]; then
        print_info ".envファイルを作成中..."
        cp .env.example .env
        
        # ランダムなCookie Secretの生成
        COOKIE_SECRET=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
        sed -i "s/your-32-character-random-string-for-cookie-encryption/$COOKIE_SECRET/" .env
        
        print_success ".envファイルが作成されました"
        print_warning "OAuth認証プロバイダーの設定を.envファイルで行ってください"
    else
        print_info ".envファイルが既に存在します"
    fi
}

# SSL証明書ディレクトリの作成
create_ssl_directory() {
    if [ ! -d "nginx/ssl" ]; then
        print_info "SSL証明書用ディレクトリを作成中..."
        mkdir -p nginx/ssl
        print_success "SSL証明書用ディレクトリが作成されました"
    fi
}

# Docker イメージのビルド
build_images() {
    print_info "Docker イメージをビルド中..."
    
    if command -v docker-compose &> /dev/null; then
        docker-compose build
    else
        docker compose build
    fi
    
    print_success "Docker イメージのビルドが完了しました"
}

# OAuth設定の確認
check_oauth_config() {
    print_info "OAuth設定の確認中..."
    
    if [ -f .env ]; then
        source .env
        
        if [ "$OAUTH2_PROXY_CLIENT_ID" = "your-github-oauth-client-id" ]; then
            print_warning "OAuth Client IDが設定されていません"
            print_warning ".envファイルでOAUTH2_PROXY_CLIENT_IDを設定してください"
        fi
        
        if [ "$OAUTH2_PROXY_CLIENT_SECRET" = "your-github-oauth-client-secret" ]; then
            print_warning "OAuth Client Secretが設定されていません"
            print_warning ".envファイルでOAUTH2_PROXY_CLIENT_SECRETを設定してください"
        fi
    fi
}

# メイン実行
main() {
    print_info "セットアップを開始します..."
    
    check_requirements
    create_env_file
    create_ssl_directory
    build_images
    check_oauth_config
    
    echo
    print_success "セットアップが完了しました！"
    echo
    echo "次のステップ:"
    echo "1. .envファイルでOAuth設定を行ってください"
    echo "2. 以下のコマンドで環境を起動してください:"
    echo "   $ ./scripts/start.sh"
    echo
    echo "詳細なドキュメントはREADME.mdを参照してください。"
}

main "$@"