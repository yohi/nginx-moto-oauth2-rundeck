# OAuth Docker Compose環境

OAuth2Proxy、Nginx、Moto（モックAWS）を統合したDocker Compose環境です。完全なOAuth認証フローをローカルでテストできます。

## 概要

この環境は以下のコンポーネントから構成されています：

- **Nginx**: リバースプロキシ（エントリポイント）
- **OAuth2Proxy**: OAuth認証サービス
- **Moto**: モックAWSサービス（S3、DynamoDB等）
- **Backend**: サンプルNode.jsアプリケーション

## アーキテクチャ

```
ユーザー → Nginx → OAuth2Proxy → OAuthプロバイダー（GitHub/Google等）
           ↓
       バックエンドアプリ → Moto（モックAWS）
```

## 前提条件

- Docker
- Docker Compose
- curl（テスト用）

## クイックスタート

### 1. セットアップ

```bash
# リポジトリをクローン
git clone <repository-url>
cd oauth-docker-compose

# セットアップスクリプトを実行
./scripts/setup.sh
```

### 2. OAuth設定

`.env`ファイルを編集して、OAuthプロバイダーの設定を行います：

#### GitHub OAuth Appの設定例

1. GitHub Settings → Developer settings → OAuth Apps で新しいアプリを作成
2. 以下の情報を設定：
   - Application name: `OAuth Docker Compose Test`
   - Homepage URL: `http://localhost`
   - Authorization callback URL: `http://localhost/oauth2/callback`

3. `.env`ファイルに情報を設定：

```bash
OAUTH2_PROXY_CLIENT_ID=your-github-client-id
OAUTH2_PROXY_CLIENT_SECRET=your-github-client-secret
OAUTH2_PROXY_PROVIDER=github
```

#### Google OAuth設定例

1. Google Cloud Console でOAuth 2.0クライアントIDを作成
2. `.env`ファイルを以下のように設定：

```bash
OAUTH2_PROXY_CLIENT_ID=your-google-client-id
OAUTH2_PROXY_CLIENT_SECRET=your-google-client-secret
OAUTH2_PROXY_PROVIDER=google
```

### 3. 起動

```bash
./scripts/start.sh
```

### 4. アクセス

ブラウザで http://localhost にアクセスします。初回アクセス時にOAuth認証にリダイレクトされます。

## 使用方法

### エンドポイント

- **メインアプリ**: http://localhost
- **ヘルスチェック**: http://localhost/health（認証不要）
- **ユーザー情報**: http://localhost/user
- **AWS状態確認**: http://localhost/aws/status
- **S3デモ**: http://localhost/aws/s3
- **DynamoDBデモ**: http://localhost/aws/dynamodb

### サービス管理

```bash
# 起動
./scripts/start.sh

# 停止
./scripts/stop.sh

# データも削除して停止
./scripts/stop.sh --volumes

# ログ確認
docker-compose logs -f [service-name]

# サービス状態確認
docker-compose ps
```

## 設定

### 環境変数

主要な環境変数は`.env`ファイルで設定します：

| 変数名 | 説明 | デフォルト値 |
|--------|------|-------------|
| `OAUTH2_PROXY_CLIENT_ID` | OAuthクライアントID | - |
| `OAUTH2_PROXY_CLIENT_SECRET` | OAuthクライアントシークレット | - |
| `OAUTH2_PROXY_PROVIDER` | OAuthプロバイダー | `github` |
| `OAUTH2_PROXY_EMAIL_DOMAINS` | 許可するメールドメイン | `*` |
| `AWS_ENDPOINT_URL` | MotoのエンドポイントURL | `http://moto:5000` |

### 対応OAuthプロバイダー

- GitHub（推奨）
- Google
- Microsoft Azure AD
- その他OAuth2Proxy対応プロバイダー

## 開発・デバッグ

### ログの確認

```bash
# 全サービスのログ
docker-compose logs -f

# 特定のサービスのログ
docker-compose logs -f nginx
docker-compose logs -f oauth2-proxy
docker-compose logs -f backend
docker-compose logs -f moto
```

### サービスの個別テスト

```bash
# Nginxヘルスチェック
curl http://localhost/health

# OAuth2Proxy直接アクセス（デバッグ用）
curl http://localhost:4180/ping

# Moto直接アクセス
curl http://localhost:5000/

# バックエンド直接アクセス（Dockerネットワーク内）
docker-compose exec nginx curl http://backend:8080/health
```

## トラブルシューティング

### よくある問題

#### 1. OAuth認証が失敗する

**症状**: 認証後にエラーページが表示される

**解決方法**:
- `.env`のOAuth設定を確認
- OAuthプロバイダーのコールバックURL設定を確認
- `docker-compose logs oauth2-proxy`でログを確認

#### 2. サービスに接続できない

**症状**: 502 Bad Gatewayエラーが発生

**解決方法**:
```bash
# サービス状態を確認
docker-compose ps

# 失敗したサービスを再起動
docker-compose restart [service-name]

# ログを確認
docker-compose logs [service-name]
```

#### 3. Moto接続エラー

**症状**: AWS APIエラーが発生

**解決方法**:
```bash
# Motoサービスの状態確認
curl http://localhost:5000/

# Motoサービス再起動
docker-compose restart moto
```

### ログレベルの変更

デバッグ時にログレベルを上げる場合：

```bash
# OAuth2Proxyのログレベルを上げる
echo "OAUTH2_PROXY_LOGGING_LEVEL=debug" >> .env
docker-compose restart oauth2-proxy
```

## セキュリティ考慮事項

### 本番環境での設定

本番環境で使用する場合は以下の設定を変更してください：

1. **HTTPS有効化**:
```bash
OAUTH2_PROXY_COOKIE_SECURE=true
```

2. **メールドメイン制限**:
```bash
OAUTH2_PROXY_EMAIL_DOMAINS=your-domain.com
```

3. **セッション有効期限**:
```bash
OAUTH2_PROXY_COOKIE_EXPIRE=1h
```

### SSL証明書

HTTPS用のSSL証明書は`nginx/ssl/`ディレクトリに配置してください：

```bash
# 自己署名証明書の作成例（開発用のみ）
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx/ssl/key.pem \
  -out nginx/ssl/cert.pem
```

## 開発への貢献

### ディレクトリ構造

```
oauth-docker-compose/
├── docker-compose.yml       # Docker Compose設定
├── .env.example            # 環境変数サンプル
├── nginx/
│   └── nginx.conf          # Nginx設定
├── backend/                # サンプルバックエンド
│   ├── Dockerfile
│   ├── package.json
│   └── server.js
├── scripts/                # 管理スクリプト
│   ├── setup.sh
│   ├── start.sh
│   └── stop.sh
└── docs/                   # ドキュメント
```

### カスタマイズ

- **Nginx設定**: `nginx/nginx.conf`を編集
- **バックエンドアプリ**: `backend/`ディレクトリ内を編集
- **OAuth設定**: `.env`ファイルを編集

## ライセンス

MIT

## サポート

問題が発生した場合は、以下の手順で情報を収集してください：

1. `docker-compose ps`の出力
2. `docker-compose logs`の出力
3. `.env`ファイルの内容（秘密情報は除く）
4. 実行した手順とエラーメッセージ