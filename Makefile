# OAuth Docker Compose環境管理用Makefile

.PHONY: help setup start stop restart status logs test validate clean build

# デフォルトターゲット
help: ## このヘルプメッセージを表示
	@echo "OAuth Docker Compose環境管理コマンド:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "使用例:"
	@echo "  make setup     # 初回セットアップ"
	@echo "  make start     # 環境を起動"
	@echo "  make test      # テストを実行"
	@echo "  make stop      # 環境を停止"

setup: ## 初回セットアップを実行
	@echo "初回セットアップを実行中..."
	@./scripts/setup.sh

validate: ## 設定を検証
	@echo "設定を検証中..."
	@./scripts/validate.sh

start: ## Docker Compose環境を起動
	@echo "Docker Compose環境を起動中..."
	@./scripts/start.sh

stop: ## Docker Compose環境を停止
	@echo "Docker Compose環境を停止中..."
	@./scripts/stop.sh

restart: stop start ## 環境を再起動

status: ## サービス状態を確認
	@echo "サービス状態を確認中..."
	@if command -v docker-compose >/dev/null 2>&1; then \
		docker-compose ps; \
	else \
		docker compose ps; \
	fi

logs: ## すべてのサービスのログを表示
	@if command -v docker-compose >/dev/null 2>&1; then \
		docker-compose logs -f; \
	else \
		docker compose logs -f; \
	fi

logs-nginx: ## Nginxのログを表示
	@if command -v docker-compose >/dev/null 2>&1; then \
		docker-compose logs -f nginx; \
	else \
		docker compose logs -f nginx; \
	fi

logs-oauth: ## OAuth2Proxyのログを表示
	@if command -v docker-compose >/dev/null 2>&1; then \
		docker-compose logs -f oauth2-proxy; \
	else \
		docker compose logs -f oauth2-proxy; \
	fi

logs-backend: ## バックエンドのログを表示
	@if command -v docker-compose >/dev/null 2>&1; then \
		docker-compose logs -f backend; \
	else \
		docker compose logs -f backend; \
	fi

logs-moto: ## Motoのログを表示
	@if command -v docker-compose >/dev/null 2>&1; then \
		docker-compose logs -f moto; \
	else \
		docker compose logs -f moto; \
	fi

test: ## 統合テストを実行
	@echo "統合テストを実行中..."
	@./scripts/test.sh

build: ## Docker イメージをビルド
	@echo "Docker イメージをビルド中..."
	@if command -v docker-compose >/dev/null 2>&1; then \
		docker-compose build; \
	else \
		docker compose build; \
	fi

rebuild: ## Docker イメージを再ビルド（キャッシュなし）
	@echo "Docker イメージを再ビルド中（キャッシュなし）..."
	@if command -v docker-compose >/dev/null 2>&1; then \
		docker-compose build --no-cache; \
	else \
		docker compose build --no-cache; \
	fi

clean: ## 未使用のDockerリソースを削除
	@echo "未使用のDockerリソースを削除中..."
	@docker system prune -f
	@docker volume prune -f

clean-all: ## すべてのDockerリソースを削除（データも含む）
	@echo "すべてのDockerリソースを削除中..."
	@./scripts/stop.sh --volumes --images
	@docker system prune -af
	@docker volume prune -f

dev-setup: setup validate ## 開発用セットアップ（セットアップ + 検証）

dev-start: validate start test ## 開発用起動（検証 + 起動 + テスト）

# 個別サービス操作
restart-nginx: ## Nginxサービスを再起動
	@if command -v docker-compose >/dev/null 2>&1; then \
		docker-compose restart nginx; \
	else \
		docker compose restart nginx; \
	fi

restart-oauth: ## OAuth2Proxyサービスを再起動
	@if command -v docker-compose >/dev/null 2>&1; then \
		docker-compose restart oauth2-proxy; \
	else \
		docker compose restart oauth2-proxy; \
	fi

restart-backend: ## バックエンドサービスを再起動
	@if command -v docker-compose >/dev/null 2>&1; then \
		docker-compose restart backend; \
	else \
		docker compose restart backend; \
	fi

restart-moto: ## Motoサービスを再起動
	@if command -v docker-compose >/dev/null 2>&1; then \
		docker-compose restart moto; \
	else \
		docker compose restart moto; \
	fi

# デバッグ用コマンド
shell-nginx: ## Nginxコンテナにシェルでアクセス
	@if command -v docker-compose >/dev/null 2>&1; then \
		docker-compose exec nginx sh; \
	else \
		docker compose exec nginx sh; \
	fi

shell-backend: ## バックエンドコンテナにシェルでアクセス
	@if command -v docker-compose >/dev/null 2>&1; then \
		docker-compose exec backend sh; \
	else \
		docker compose exec backend sh; \
	fi

health-check: ## ヘルスチェックを実行
	@echo "ヘルスチェックを実行中..."
	@curl -s http://localhost/health || echo "ヘルスチェック失敗"
	@curl -s http://localhost:4180/ping || echo "OAuth2Proxy ping失敗"  
	@curl -s http://localhost:5000/ || echo "Moto接続失敗"

# 環境情報
info: ## 環境情報を表示
	@echo "=== OAuth Docker Compose環境情報 ==="
	@echo "Docker バージョン:"
	@docker --version
	@echo ""
	@if command -v docker-compose >/dev/null 2>&1; then \
		echo "Docker Compose バージョン:"; \
		docker-compose --version; \
	else \
		echo "Docker Compose バージョン:"; \
		docker compose version; \
	fi
	@echo ""
	@echo "プロジェクト構造:"
	@find . -type f -name "*.yml" -o -name "*.yaml" -o -name "*.conf" -o -name "*.sh" -o -name "Dockerfile" -o -name "package.json" | sort
	@echo ""
	@if [ -f .env ]; then \
		echo ".env ファイル: 存在"; \
		echo "設定済み変数数: $$(grep -c "^[^#]" .env)"; \
	else \
		echo ".env ファイル: 未作成"; \
	fi