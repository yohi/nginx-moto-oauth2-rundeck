#!/bin/bash

# OAuth Docker Compose環境停止スクリプト

set -e

echo "=================================================="
echo "OAuth Docker Compose環境停止スクリプト"
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

# Docker Composeサービスの停止
stop_services() {
    print_info "Docker Composeサービスを停止中..."
    
    if command -v docker-compose &> /dev/null; then
        docker-compose down
    else
        docker compose down
    fi
    
    print_success "すべてのサービスが停止されました"
}

# ボリューム削除オプション
cleanup_volumes() {
    if [ "$1" = "--volumes" ] || [ "$1" = "-v" ]; then
        print_warning "ボリュームも削除します（データが失われます）"
        read -p "続行しますか？ (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if command -v docker-compose &> /dev/null; then
                docker-compose down -v
            else
                docker compose down -v
            fi
            print_success "ボリュームも削除されました"
        else
            print_info "ボリューム削除をキャンセルしました"
        fi
    fi
}

# イメージ削除オプション
cleanup_images() {
    if [ "$1" = "--images" ] || [ "$2" = "--images" ]; then
        print_warning "ビルドされたイメージも削除します"
        read -p "続行しますか？ (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if command -v docker-compose &> /dev/null; then
                docker-compose down --rmi local
            else
                docker compose down --rmi local
            fi
            print_success "ローカルイメージも削除されました"
        else
            print_info "イメージ削除をキャンセルしました"
        fi
    fi
}

# 使用方法の表示
show_usage() {
    echo "使用方法:"
    echo "  ./scripts/stop.sh                 # サービスのみ停止"
    echo "  ./scripts/stop.sh --volumes       # サービスとボリュームを停止・削除"
    echo "  ./scripts/stop.sh --images        # サービスとローカルイメージを停止・削除"
    echo "  ./scripts/stop.sh -v --images     # すべてを停止・削除"
}

# メイン実行
main() {
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        show_usage
        exit 0
    fi
    
    print_info "環境を停止します..."
    
    stop_services
    cleanup_volumes "$1"
    cleanup_images "$1" "$2"
    
    echo
    print_success "停止処理が完了しました"
    echo
    echo "再起動方法:"
    echo "  $ ./scripts/start.sh"
    echo
}

main "$@"