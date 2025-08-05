#!/bin/bash

# OAuth Docker Compose環境設定検証スクリプト

set -e

echo "=================================================="
echo "OAuth Docker Compose環境設定検証スクリプト"
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

# 検証結果の集計
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# 検証結果を記録する関数
record_check() {
    local check_name="$1"
    local result="$2"
    local message="$3"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    case "$result" in
        "PASS")
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
            print_success "✓ $check_name"
            if [ -n "$message" ]; then
                echo "  $message"
            fi
            ;;
        "WARN")
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            print_warning "⚠ $check_name"
            if [ -n "$message" ]; then
                echo "  $message"
            fi
            ;;
        "FAIL")
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
            print_error "✗ $check_name"
            if [ -n "$message" ]; then
                echo "  $message"
            fi
            ;;
    esac
}

# 必要なツールの確認
validate_prerequisites() {
    print_info "前提条件の確認中..."
    
    # Docker確認
    if command -v docker &> /dev/null; then
        local docker_version=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
        record_check "Docker インストール確認" "PASS" "バージョン: $docker_version"
    else
        record_check "Docker インストール確認" "FAIL" "Dockerがインストールされていません"
    fi
    
    # Docker Compose確認
    if command -v docker-compose &> /dev/null; then
        local compose_version=$(docker-compose --version | cut -d' ' -f3 | cut -d',' -f1)
        record_check "Docker Compose インストール確認" "PASS" "バージョン: $compose_version"
    elif docker compose version &> /dev/null; then
        local compose_version=$(docker compose version --short)
        record_check "Docker Compose インストール確認" "PASS" "バージョン: $compose_version"
    else
        record_check "Docker Compose インストール確認" "FAIL" "Docker Composeがインストールされていません"
    fi
    
    # curl確認
    if command -v curl &> /dev/null; then
        record_check "curl インストール確認" "PASS"
    else
        record_check "curl インストール確認" "WARN" "テスト用にcurlの使用を推奨します"
    fi
    
    # openssl確認
    if command -v openssl &> /dev/null; then
        record_check "openssl インストール確認" "PASS"
    else
        record_check "openssl インストール確認" "WARN" "セキュアな秘密鍵生成にopensslの使用を推奨します"
    fi
}

# ファイル構造の確認
validate_file_structure() {
    print_info "ファイル構造の確認中..."
    
    # 必須ファイルの確認
    local required_files=(
        "docker-compose.yml"
        ".env.example"
        "nginx/nginx.conf"
        "backend/Dockerfile"
        "backend/package.json"
        "backend/server.js"
        "README.md"
    )
    
    for file in "${required_files[@]}"; do
        if [ -f "$file" ]; then
            record_check "ファイル存在確認: $file" "PASS"
        else
            record_check "ファイル存在確認: $file" "FAIL" "必須ファイルが見つかりません"
        fi
    done
    
    # 必須ディレクトリの確認
    local required_dirs=(
        "nginx"
        "backend"
        "scripts"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [ -d "$dir" ]; then
            record_check "ディレクトリ存在確認: $dir" "PASS"
        else
            record_check "ディレクトリ存在確認: $dir" "FAIL" "必須ディレクトリが見つかりません"
        fi
    done
    
    # スクリプトの実行権限確認
    local scripts=(
        "scripts/setup.sh"
        "scripts/start.sh"
        "scripts/stop.sh"
        "scripts/test.sh"
        "scripts/validate.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            if [ -x "$script" ]; then
                record_check "スクリプト実行権限確認: $script" "PASS"
            else
                record_check "スクリプト実行権限確認: $script" "WARN" "実行権限がありません: chmod +x $script"
            fi
        fi
    done
}

# 環境変数設定の検証
validate_environment_config() {
    print_info "環境変数設定の検証中..."
    
    if [ -f .env ]; then
        record_check ".env ファイル存在確認" "PASS"
        source .env
        
        # OAuth2Proxy設定の確認
        if [ -n "$OAUTH2_PROXY_CLIENT_ID" ] && [ "$OAUTH2_PROXY_CLIENT_ID" != "your-github-oauth-client-id" ]; then
            record_check "OAUTH2_PROXY_CLIENT_ID 設定" "PASS"
        else
            record_check "OAUTH2_PROXY_CLIENT_ID 設定" "WARN" "OAuthクライアントIDが設定されていません"
        fi
        
        if [ -n "$OAUTH2_PROXY_CLIENT_SECRET" ] && [ "$OAUTH2_PROXY_CLIENT_SECRET" != "your-github-oauth-client-secret" ]; then
            record_check "OAUTH2_PROXY_CLIENT_SECRET 設定" "PASS"
        else
            record_check "OAUTH2_PROXY_CLIENT_SECRET 設定" "WARN" "OAuthクライアントシークレットが設定されていません"
        fi
        
        if [ -n "$OAUTH2_PROXY_COOKIE_SECRET" ] && [ ${#OAUTH2_PROXY_COOKIE_SECRET} -ge 32 ]; then
            record_check "OAUTH2_PROXY_COOKIE_SECRET 設定" "PASS" "長さ: ${#OAUTH2_PROXY_COOKIE_SECRET}文字"
        else
            record_check "OAUTH2_PROXY_COOKIE_SECRET 設定" "FAIL" "32文字以上のランダムな文字列が必要です"
        fi
        
        # プロバイダー設定の確認
        case "$OAUTH2_PROXY_PROVIDER" in
            "github"|"google"|"oidc")
                record_check "OAUTH2_PROXY_PROVIDER 設定" "PASS" "プロバイダー: $OAUTH2_PROXY_PROVIDER"
                ;;
            *)
                record_check "OAUTH2_PROXY_PROVIDER 設定" "WARN" "サポートされていないプロバイダー: $OAUTH2_PROXY_PROVIDER"
                ;;
        esac
        
        # セキュリティ設定の確認
        if [ "$OAUTH2_PROXY_COOKIE_SECURE" = "true" ]; then
            record_check "セキュリティ設定: COOKIE_SECURE" "PASS" "本番環境に適した設定です"
        else
            record_check "セキュリティ設定: COOKIE_SECURE" "WARN" "本番環境では true を推奨します"
        fi
        
    else
        record_check ".env ファイル存在確認" "FAIL" ".envファイルが見つかりません。./scripts/setup.shを実行してください"
    fi
}

# Docker Compose設定の検証
validate_docker_compose_config() {
    print_info "Docker Compose設定の検証中..."
    
    if [ -f docker-compose.yml ]; then
        # YAML構文の検証
        if command -v docker-compose &> /dev/null; then
            if docker-compose config > /dev/null 2>&1; then
                record_check "Docker Compose YAML構文" "PASS"
            else
                record_check "Docker Compose YAML構文" "FAIL" "YAML構文エラーがあります"
            fi
        elif docker compose config > /dev/null 2>&1; then
            record_check "Docker Compose YAML構文" "PASS"
        else
            record_check "Docker Compose YAML構文" "FAIL" "YAML構文エラーがあります"
        fi
        
        # 必要なサービスの確認
        local required_services=("nginx" "oauth2-proxy" "moto" "backend")
        for service in "${required_services[@]}"; do
            if grep -q "^  $service:" docker-compose.yml; then
                record_check "Docker Composeサービス定義: $service" "PASS"
            else
                record_check "Docker Composeサービス定義: $service" "FAIL" "サービス定義が見つかりません"
            fi
        done
        
        # ネットワーク定義の確認
        if grep -q "^networks:" docker-compose.yml; then
            record_check "Docker Composeネットワーク定義" "PASS"
        else
            record_check "Docker Composeネットワーク定義" "WARN" "ネットワーク定義が見つかりません"
        fi
        
    else
        record_check "docker-compose.yml 存在確認" "FAIL" "Docker Compose設定ファイルが見つかりません"
    fi
}

# Nginx設定の検証
validate_nginx_config() {
    print_info "Nginx設定の検証中..."
    
    if [ -f nginx/nginx.conf ]; then
        record_check "Nginx設定ファイル存在確認" "PASS"
        
        # 重要な設定項目の確認
        if grep -q "upstream oauth2_proxy" nginx/nginx.conf; then
            record_check "Nginx OAuth2Proxyアップストリーム設定" "PASS"
        else
            record_check "Nginx OAuth2Proxyアップストリーム設定" "FAIL"
        fi
        
        if grep -q "upstream backend" nginx/nginx.conf; then
            record_check "Nginx バックエンドアップストリーム設定" "PASS"
        else
            record_check "Nginx バックエンドアップストリーム設定" "FAIL"
        fi
        
        if grep -q "auth_request /oauth2/auth" nginx/nginx.conf; then
            record_check "Nginx OAuth認証設定" "PASS"
        else
            record_check "Nginx OAuth認証設定" "FAIL"
        fi
        
        # セキュリティヘッダーの確認
        if grep -q "X-Frame-Options" nginx/nginx.conf; then
            record_check "Nginx セキュリティヘッダー設定" "PASS"
        else
            record_check "Nginx セキュリティヘッダー設定" "WARN" "セキュリティヘッダーの追加を推奨します"
        fi
        
    else
        record_check "Nginx設定ファイル存在確認" "FAIL"
    fi
}

# バックエンド設定の検証
validate_backend_config() {
    print_info "バックエンド設定の検証中..."
    
    # package.json確認
    if [ -f backend/package.json ]; then
        record_check "Backend package.json 存在確認" "PASS"
        
        # 必要な依存関係の確認
        local required_deps=("express" "aws-sdk")
        for dep in "${required_deps[@]}"; do
            if grep -q "\"$dep\"" backend/package.json; then
                record_check "Backend 依存関係: $dep" "PASS"
            else
                record_check "Backend 依存関係: $dep" "WARN" "推奨依存関係が見つかりません"
            fi
        done
    else
        record_check "Backend package.json 存在確認" "FAIL"
    fi
    
    # Dockerfile確認
    if [ -f backend/Dockerfile ]; then
        record_check "Backend Dockerfile 存在確認" "PASS"
        
        # セキュリティ設定の確認
        if grep -q "USER nodejs" backend/Dockerfile; then
            record_check "Backend Dockerfile 非rootユーザー設定" "PASS"
        else
            record_check "Backend Dockerfile 非rootユーザー設定" "WARN" "セキュリティ向上のため非rootユーザーの使用を推奨します"
        fi
        
        if grep -q "HEALTHCHECK" backend/Dockerfile; then
            record_check "Backend Dockerfile ヘルスチェック設定" "PASS"
        else
            record_check "Backend Dockerfile ヘルスチェック設定" "WARN" "ヘルスチェック設定を推奨します"
        fi
    else
        record_check "Backend Dockerfile 存在確認" "FAIL"
    fi
}

# ポート競合の確認
validate_port_conflicts() {
    print_info "ポート競合の確認中..."
    
    local ports=("80" "443" "4180" "5000" "8080")
    
    for port in "${ports[@]}"; do
        if command -v netstat &> /dev/null; then
            if netstat -tuln | grep -q ":$port "; then
                record_check "ポート$port 使用状況" "WARN" "ポートが既に使用されています"
            else
                record_check "ポート$port 使用状況" "PASS"
            fi
        elif command -v ss &> /dev/null; then
            if ss -tuln | grep -q ":$port "; then
                record_check "ポート$port 使用状況" "WARN" "ポートが既に使用されています"
            else
                record_check "ポート$port 使用状況" "PASS"
            fi
        else
            record_check "ポート使用状況確認ツール" "WARN" "netstatまたはssが利用できません"
            break
        fi
    done
}

# 総合レポートの出力
print_validation_summary() {
    echo
    echo "=================================================="
    echo "設定検証結果サマリー"
    echo "=================================================="
    echo "総チェック数: $TOTAL_CHECKS"
    echo "成功: $PASSED_CHECKS"
    echo "警告: $WARNING_CHECKS"
    echo "失敗: $FAILED_CHECKS"
    echo
    
    if [ $FAILED_CHECKS -eq 0 ]; then
        if [ $WARNING_CHECKS -eq 0 ]; then
            print_success "すべての設定検証が成功しました！"
            echo "環境は正常に設定されており、起動準備が整っています。"
        else
            print_warning "基本設定は正常ですが、$WARNING_CHECKS 件の警告があります。"
            echo "必要に応じて設定を見直してください。"
        fi
    else
        print_error "$FAILED_CHECKS 件の設定エラーがあります。"
        echo "これらの問題を解決してから環境を起動してください。"
    fi
    
    echo
    echo "次のステップ:"
    if [ $FAILED_CHECKS -eq 0 ]; then
        echo "  $ ./scripts/start.sh    # 環境を起動"
        echo "  $ ./scripts/test.sh     # 統合テストを実行"
    else
        echo "  設定エラーを修正してから再度検証してください"
        echo "  $ ./scripts/validate.sh"
    fi
    
    echo
    echo "検証完了時刻: $(date)"
    echo "=================================================="
}

# メイン実行
main() {
    print_info "設定検証を開始します..."
    echo
    
    validate_prerequisites
    validate_file_structure
    validate_environment_config
    validate_docker_compose_config
    validate_nginx_config
    validate_backend_config
    validate_port_conflicts
    
    print_validation_summary
    
    if [ $FAILED_CHECKS -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

main "$@"