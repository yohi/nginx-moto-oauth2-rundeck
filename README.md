# OAuth Docker Compose環境 with AWS Cognito & Rundeck

OAuth2Proxy、Nginx、Moto（モックAWS）、Rundeckを統合したDocker Compose環境です。完全なOAuth認証フローをローカルでテストできる包括的な認証基盤システムです。

## 🎯 概要

この環境は以下のコンポーネントから構成された**エンタープライズレベルの認証基盤**です：

- **Nginx**: リバースプロキシ・認証ゲートウェイ（ポート9000/9443）
- **OAuth2Proxy**: OAuth認証サービス（ポート4180）
- **Moto**: モックAWSサービス（Cognito、S3、DynamoDB等、ポート5000）
- **Backend**: 認証対応Node.jsアプリケーション（ポート8090）
- **Rundeck**: ワークフロー管理システム（ポート4440）
- **Cognito Setup**: AWS Cognito自動初期化サービス

## 🏗️ アーキテクチャ

```
ユーザー → Nginx (9000) → 認証チェック → OAuth2Proxy/Cognito
                ↓                              ↓
           認証OK → Backend (8090)          Moto AWS (5000)
                ↓                              ↓
           認証OK → Rundeck (4440)         Cognito User Pool
```

### 認証フロー

1. **ユーザーアクセス**: `http://localhost:9000`
2. **認証チェック**: Nginxが認証状態を確認
3. **OAuth2認証**: 未認証の場合 → `/oauth2/start` → Cognito認証
4. **認証完了**: セッション設定 → バックエンド/Rundeck へアクセス可能

## 🚀 クイックスタート

### 1. セットアップ & 起動

```bash
# リポジトリをクローン
git clone <repository-url>
cd oauth-docker-compose

# 一括セットアップ & 起動
make setup && make start

# または個別実行
./scripts/setup.sh
./scripts/start.sh
```

### 2. アクセス

```bash
# メインエントリポイント
open http://localhost:9000

# OAuth認証開始
open http://localhost:9000/oauth2/start

# Rundeck直接アクセス（認証後）
open http://localhost:9000/rundeck/
```

### 3. テストユーザー

デフォルトのテストユーザーが自動作成されます：

- **Email**: `testuser@example.com`
- **Password**: `TestPass123!`

## 📋 主要エンドポイント

### パブリックエンドポイント（認証不要）
- **ヘルスチェック**: `http://localhost:9000/health`
- **OAuth認証開始**: `http://localhost:9000/oauth2/start`
- **OAuth認証コールバック**: `http://localhost:9000/oauth2/callback`

### 認証必須エンドポイント
- **メインアプリ**: `http://localhost:9000/`
- **ユーザー情報**: `http://localhost:9000/user`
- **AWS状態確認**: `http://localhost:9000/aws/status`
- **Rundeck**: `http://localhost:9000/rundeck/`

### 開発・デバッグ用エンドポイント
- **Backend直接**: `http://localhost:8090`
- **Rundeck直接**: `http://localhost:4440`
- **Moto直接**: `http://localhost:5000`
- **OAuth2Proxy**: `http://localhost:4180`

## 🛠️ サービス管理

### Makeコマンド（推奨）

```bash
# セットアップ
make setup

# 起動
make start

# 停止
make stop

# 完全削除（ボリューム含む）
make clean

# 状態確認
make status

# ログ確認
make logs

# テスト実行
make test

# 設定検証
make validate
```

### Docker Composeコマンド

```bash
# 起動
./scripts/start.sh

# 停止
./scripts/stop.sh

# 状態確認
docker-compose ps

# ログ確認
docker-compose logs -f [service-name]

# 個別サービス再起動
docker-compose restart [service-name]
```

## ⚙️ 設定

### 主要設定ファイル

| ファイル                   | 説明                          |
| -------------------------- | ----------------------------- |
| `docker-compose.yml`       | サービス構成・環境変数        |
| `nginx/nginx.conf`         | Nginx設定（認証ゲートウェイ） |
| `backend/server.js`        | バックエンドアプリ設定        |
| `scripts/setup-cognito.js` | Cognito初期化設定             |

### 環境変数

主要な環境変数はdocker-compose.ymlで管理されています：

#### OAuth2Proxy設定
```yaml
OAUTH2_PROXY_PROVIDER: oidc
OAUTH2_PROXY_OIDC_ISSUER_URL: http://localhost:5000
OAUTH2_PROXY_CLIENT_ID: oauth-app-client
OAUTH2_PROXY_CLIENT_SECRET: oauth-app-secret
```

#### AWS Cognito設定
```yaml
AWS_ENDPOINT_URL: http://moto:5000
AWS_ACCESS_KEY_ID: testing
AWS_SECRET_ACCESS_KEY: testing
AWS_DEFAULT_REGION: us-east-1
```

#### Rundeck設定
```yaml
RUNDECK_GRAILS_URL: http://localhost:9000/rundeck
RUNDECK_PREAUTH_ENABLED: true
RUNDECK_PREAUTH_USERNAME_HEADER: X-Auth-Request-Email
```

## 🔍 開発・デバッグ

### ログの確認

```bash
# 全サービスのログ
make logs

# 特定サービスのログ
docker-compose logs -f nginx
docker-compose logs -f backend
docker-compose logs -f rundeck
docker-compose logs -f moto
```

### 認証状態の確認

```bash
# ユーザー認証状態
curl -b cookies.txt http://localhost:9000/user

# Cognito状態
curl http://localhost:5000/moto-api/reset

# OAuth2Proxy状態
curl http://localhost:4180/ping
```

### 手動テスト手順

```bash
# 1. 認証状態確認
curl http://localhost:9000/user

# 2. OAuth認証開始
curl -c cookies.txt -L http://localhost:9000/oauth2/start

# 3. 手動セッション設定（テスト用）
curl -X POST http://localhost:9000/auth/test-session \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser@example.com","password":"TestPass123!"}'

# 4. Rundeckアクセステスト
curl -b cookies.txt http://localhost:9000/rundeck/
```

## 🎨 機能詳細

### 1. OAuth認証フロー
- **プロバイダー**: AWS Cognito（Moto）
- **認証方式**: OIDC (OpenID Connect)
- **セッション管理**: Cookie & JWTベース
- **自動リダイレクト**: 未認証時の自動認証ページリダイレクト

### 2. Rundeck統合
- **認証連携**: プリ認証（Pre-auth）方式
- **ユーザー情報**: Cognitoから自動取得
- **プロジェクト管理**: 認証後即座に利用可能
- **レイアウト**: CSP制約を解決し完全動作

### 3. AWS モック環境
- **サービス**: Cognito、S3、DynamoDB
- **ユーザープール**: 自動作成・設定
- **テストデータ**: サンプルユーザー自動投入

### 4. セキュリティ設定
- **認証ゲートウェイ**: Nginx auth_request
- **セッション保護**: httpOnly、secure cookie
- **ヘッダー検証**: 認証情報の自動ヘッダー追加

## 🛡️ セキュリティ考慮事項

### 開発環境設定（現在）
- CSPヘッダー無効化（Rundeck動作のため）
- HTTP接続許可
- 全ドメイン許可

### 本番環境推奨設定

```yaml
# HTTPS有効化
OAUTH2_PROXY_COOKIE_SECURE: true
OAUTH2_PROXY_REDIRECT_URL: https://your-domain.com/oauth2/callback

# ドメイン制限
OAUTH2_PROXY_EMAIL_DOMAINS: your-company.com

# CSP有効化
# nginx.conf内のCSPヘッダーを適切に設定
```

## 🐛 トラブルシューティング

### よくある問題と解決法

#### 1. 認証ループが発生する
```bash
# 症状: 認証完了後もリダイレクトが続く
# 解決: セッション状態とCookieを確認
make clean && make setup && make start
```

#### 2. Rundeckのレイアウトが崩れる
```bash
# 症状: CSSが読み込まれない、ボタンが動作しない
# 解決: CSP設定とアセットプロキシを確認
docker-compose restart nginx
```

#### 3. OAuth認証エラー
```bash
# 症状: Cognito認証が失敗する
# 解決: Moto状態とCognito設定を確認
docker-compose logs moto
docker-compose restart cognito-setup
```

#### 4. 502 Bad Gateway
```bash
# 症状: サービスに接続できない
# 解決: サービス起動状態を確認
make status
docker-compose restart [failed-service]
```

### ログ分析

```bash
# エラーパターン別ログ確認
docker-compose logs nginx | grep -i error
docker-compose logs backend | grep -i auth
docker-compose logs rundeck | grep -i login
```

### 設定検証

```bash
# 自動検証スクリプト
./scripts/validate.sh

# 手動検証
make validate
```

## 📁 ディレクトリ構造

```
oauth-docker-compose/
├── docker-compose.yml          # メインサービス構成
├── Makefile                    # 管理コマンド定義
├── README.md                   # このファイル
├── design.md                   # システム設計書
├── requirements.md             # 要件定義書
├── tasks.md                    # 実装タスク管理
├── backend/                    # Node.jsバックエンド
│   ├── Dockerfile
│   ├── package.json
│   ├── server.js              # 認証統合サーバー
│   └── cognito-auth.js        # Cognito認証ロジック
├── nginx/                      # Nginx設定
│   ├── nginx.conf             # 認証ゲートウェイ設定
│   └── ssl/                   # SSL証明書配置場所
├── rundeck/                    # Rundeck設定
│   └── config/                # 設定ファイル
├── cognito-setup/             # Cognito初期化
│   └── Dockerfile
├── scripts/                   # 管理スクリプト
│   ├── setup.sh              # 初期セットアップ
│   ├── start.sh               # サービス起動
│   ├── stop.sh                # サービス停止
│   ├── test.sh                # 統合テスト
│   ├── validate.sh            # 設定検証
│   └── setup-cognito.js       # Cognito設定スクリプト
└── docs/                      # 詳細ドキュメント
```

## 🧪 テスト

### 自動テスト

```bash
# 統合テスト実行
make test

# 個別テスト
./scripts/test.sh
```

### Playwright E2Eテスト

```bash
# ブラウザ自動テスト（要：Playwright MCP）
# 1. OAuth認証フロー
# 2. Rundeck機能動作
# 3. レイアウト検証
```

### 手動テストシナリオ

1. **認証フロー**:
   - `http://localhost:9000` → 認証リダイレクト → ログイン → ダッシュボード

2. **Rundeck操作**:
   - プロジェクト作成 → ジョブ定義 → 実行テスト

3. **AWS連携**:
   - S3バケット操作 → DynamoDB テーブル操作

## 🤝 開発への貢献

### 開発環境セットアップ

```bash
# 開発環境準備
git clone <repository>
cd oauth-docker-compose
make setup

# 開発サーバー起動
make start

# 開発中の再起動
make restart
```

### カスタマイズポイント

1. **認証プロバイダー変更**: `scripts/setup-cognito.js`
2. **認証ポリシー**: `nginx/nginx.conf`
3. **Rundeck設定**: `rundeck/config/`
4. **バックエンドAPI**: `backend/server.js`

### コード貢献

1. Forkしてブランチ作成
2. 変更実装・テスト追加
3. `make test`でテスト実行
4. Pull Request作成

## 📊 実装ステータス

### ✅ 完了機能
- OAuth2 Cognito認証フロー
- Nginx認証ゲートウェイ
- Rundeck統合・認証連携
- レイアウト問題の完全解決
- CSP制約の解決
- 自動セットアップスクリプト
- 統合テスト環境

### 🔄 今後の拡張予定
- HTTPS対応
- マルチテナント対応
- 詳細監査ログ
- Grafana監視ダッシュボード
- Kubernetes対応

## 📝 ライセンス

MIT License

## 🆘 サポート

問題が発生した場合は、以下の情報と共にIssueを作成してください：

1. **環境情報**:
   ```bash
   docker --version
   docker-compose --version
   make status
   ```

2. **ログ情報**:
   ```bash
   make logs > logs.txt
   ```

3. **再現手順**: 実行したコマンドとエラーメッセージ

4. **期待する動作**: 想定していた結果

---

**🎉 このシステムは、OAuth認証統合、Rundeck管理、AWS連携を1つの環境で提供する包括的な認証基盤です。**
