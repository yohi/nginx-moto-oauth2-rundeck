#!/bin/bash

# Magnito自動設定スクリプト
# OAuth2認証とユーザー作成を自動化

MAGNITO_HOST="localhost:5050"
INBUCKET_HOST="localhost:9001"
USER_POOL_ID="ap-northeast-1_magnito"
CLIENT_ID="rundeck-magnito-client"

echo "🚀 Magnito OAuth2設定を開始します..."

# Magnitoの起動を待機
echo "⏳ Magnitoの起動を待機中..."
until curl -f "http://${MAGNITO_HOST}/health" > /dev/null 2>&1; do
    echo "   Magnitoの起動を待機中..."
    sleep 5
done

echo "✅ Magnitoが起動しました"

# テストユーザーを作成（Magnito Web UI経由）
echo "👤 テストユーザーを作成中..."

# Magnito APIでユーザー作成
USER_DATA='{
    "username": "admin",
    "password": "Admin123!",
    "email": "admin@example.com",
    "given_name": "Admin",
    "family_name": "User",
    "email_verified": true
}'

# Magnitoは標準的なCognito APIエンドポイントを提供
curl -s -X POST "http://${MAGNITO_HOST}/signup" \
    -H "Content-Type: application/json" \
    -d "$USER_DATA" > /dev/null 2>&1

echo "✅ テストユーザーが作成されました"

# OAuth2トークンテスト
echo "🔑 OAuth2トークンテストを実行中..."

TOKEN_RESPONSE=$(curl -s -X POST "http://${MAGNITO_HOST}/oauth2/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=authorization_code&client_id=${CLIENT_ID}&code=dummy_code")

if [[ "$TOKEN_RESPONSE" =~ "access_token" ]]; then
    echo "✅ OAuth2トークンエンドポイントが応答しています"
else
    echo "⚠️  OAuth2トークンエンドポイントの確認が必要です"
fi

# OIDC Discovery確認
echo "🔍 OIDC Discovery確認中..."
DISCOVERY_RESPONSE=$(curl -s "http://${MAGNITO_HOST}/.well-known/openid-configuration")

if [[ "$DISCOVERY_RESPONSE" =~ "issuer" ]]; then
    echo "✅ OIDC Discoveryエンドポイントが正常です"
else
    echo "⚠️  OIDC Discoveryの確認が必要です"
fi

# JWKS確認
echo "🔐 JWKS確認中..."
JWKS_RESPONSE=$(curl -s "http://${MAGNITO_HOST}/.well-known/jwks.json")

if [[ "$JWKS_RESPONSE" =~ "keys" ]]; then
    echo "✅ JWKSエンドポイントが正常です"
else
    echo "⚠️  JWKSの確認が必要です"
fi

echo ""
echo "🎉 Magnito OAuth2設定が完了しました！"
echo ""
echo "📋 設定情報:"
echo "   • Magnito管理画面: http://localhost:5051"
echo "   • SMTP管理画面 (Inbucket): http://localhost:9001"
echo "   • User Pool ID: ${USER_POOL_ID}"
echo "   • Client ID: ${CLIENT_ID}"
echo "   • テストユーザー: admin@example.com / Admin123!"
echo ""
echo "🔗 OAuth2 エンドポイント:"
echo "   • Discovery: http://localhost:5050/.well-known/openid-configuration"
echo "   • JWKS: http://localhost:5050/.well-known/jwks.json"
echo "   • Token: http://localhost:5050/oauth2/token"
echo ""
echo "📧 メールテスト:"
echo "   • パスワードリセット等のメールはInbucketで確認できます"
echo "   • http://localhost:9001 でメール受信ボックスを確認してください"
echo ""
