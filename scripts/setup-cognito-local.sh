#!/bin/bash

# cognito-local自動設定スクリプト
# User Pool、クライアント、ユーザー作成を自動化

COGNITO_LOCAL_HOST="localhost:9229"
USER_POOL_NAME="rundeck"
CLIENT_ID="rundeck-client"
CLIENT_SECRET="rundeck-client-secret"
REGION="us-east-1"

echo "🚀 cognito-local OAuth2設定を開始します..."

# cognito-localの起動を待機
echo "⏳ cognito-localの起動を待機中..."
until curl -f "http://${COGNITO_LOCAL_HOST}/health" > /dev/null 2>&1; do
    echo "   cognito-localの起動を待機中..."
    sleep 5
done

echo "✅ cognito-localが起動しました"

# AWS CLI設定（ローカル向け）
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=${REGION}

# User Poolを作成
echo "🏢 User Poolを作成中..."
USER_POOL_RESPONSE=$(aws cognito-idp create-user-pool \
    --endpoint-url "http://${COGNITO_LOCAL_HOST}" \
    --pool-name "${USER_POOL_NAME}" \
    --policies '{
        "PasswordPolicy": {
            "MinimumLength": 8,
            "RequireUppercase": false,
            "RequireLowercase": false,
            "RequireNumbers": false,
            "RequireSymbols": false
        }
    }' \
    --auto-verified-attributes email \
    --username-attributes email \
    --schema '[
        {
            "Name": "email",
            "AttributeDataType": "String",
            "Mutable": true,
            "Required": true
        },
        {
            "Name": "given_name",
            "AttributeDataType": "String",
            "Mutable": true
        },
        {
            "Name": "family_name",
            "AttributeDataType": "String",
            "Mutable": true
        }
    ]' \
    --output json)

if [ $? -eq 0 ]; then
    USER_POOL_ID=$(echo "$USER_POOL_RESPONSE" | jq -r '.UserPool.Id')
    echo "✅ User Pool作成成功: ${USER_POOL_ID}"
else
    echo "❌ User Pool作成失敗"
    exit 1
fi

# User Pool Clientを作成
echo "📱 User Pool Clientを作成中..."
CLIENT_RESPONSE=$(aws cognito-idp create-user-pool-client \
    --endpoint-url "http://${COGNITO_LOCAL_HOST}" \
    --user-pool-id "${USER_POOL_ID}" \
    --client-name "${CLIENT_ID}" \
    --generate-secret \
    --explicit-auth-flows ALLOW_USER_PASSWORD_AUTH ALLOW_REFRESH_TOKEN_AUTH \
    --supported-identity-providers COGNITO \
    --callback-urls "http://localhost:9000/oauth2/callback" \
    --logout-urls "http://localhost:9000/oauth2/sign_out" \
    --allowed-o-auth-flows authorization_code \
    --allowed-o-auth-scopes openid email profile \
    --allowed-o-auth-flows-user-pool-client \
    --output json)

if [ $? -eq 0 ]; then
    echo "✅ User Pool Client作成成功"
else
    echo "❌ User Pool Client作成失敗"
    exit 1
fi

# テストユーザーを作成
echo "👤 テストユーザーを作成中..."
USER_RESPONSE=$(aws cognito-idp admin-create-user \
    --endpoint-url "http://${COGNITO_LOCAL_HOST}" \
    --user-pool-id "${USER_POOL_ID}" \
    --username "admin" \
    --user-attributes '[
        {
            "Name": "email",
            "Value": "admin@example.com"
        },
        {
            "Name": "given_name",
            "Value": "Admin"
        },
        {
            "Name": "family_name",
            "Value": "User"
        }
    ]' \
    --temporary-password "TempPass123!" \
    --message-action SUPPRESS \
    --output json)

if [ $? -eq 0 ]; then
    echo "✅ テストユーザー作成成功"
else
    echo "❌ テストユーザー作成失敗"
    # 既に存在する場合は継続
fi

# パスワードを永続化
echo "🔑 ユーザーパスワードを設定中..."
aws cognito-idp admin-set-user-password \
    --endpoint-url "http://${COGNITO_LOCAL_HOST}" \
    --user-pool-id "${USER_POOL_ID}" \
    --username "admin" \
    --password "Admin123!" \
    --permanent \
    --output json > /dev/null 2>&1

echo "✅ パスワード設定完了"

# OIDC Discoveryエンドポイント確認
echo "🔍 OIDC Discovery確認中..."
DISCOVERY_URL="http://${COGNITO_LOCAL_HOST}/${USER_POOL_ID}/.well-known/openid-configuration"
DISCOVERY_RESPONSE=$(curl -s "$DISCOVERY_URL")

if [[ "$DISCOVERY_RESPONSE" =~ "issuer" ]]; then
    echo "✅ OIDC Discoveryエンドポイントが正常です"
else
    echo "⚠️  OIDC Discoveryの確認が必要です"
fi

# JWKS確認
echo "🔐 JWKS確認中..."
JWKS_URL="http://${COGNITO_LOCAL_HOST}/${USER_POOL_ID}/.well-known/jwks.json"
JWKS_RESPONSE=$(curl -s "$JWKS_URL")

if [[ "$JWKS_RESPONSE" =~ "keys" ]]; then
    echo "✅ JWKSエンドポイントが正常です"
else
    echo "⚠️  JWKSの確認が必要です"
fi

echo ""
echo "🎉 cognito-local OAuth2設定が完了しました！"
echo ""
echo "📋 設定情報:"
echo "   • cognito-local管理: http://localhost:9229"
echo "   • User Pool ID: ${USER_POOL_ID}"
echo "   • Client ID: ${CLIENT_ID}"
echo "   • Client Secret: ${CLIENT_SECRET}"
echo "   • テストユーザー: admin@example.com / Admin123!"
echo ""
echo "🔗 OAuth2 エンドポイント:"
echo "   • Discovery: ${DISCOVERY_URL}"
echo "   • JWKS: ${JWKS_URL}"
echo "   • Authorization: http://localhost:9229/${USER_POOL_ID}/oauth2/authorize"
echo "   • Token: http://localhost:9229/${USER_POOL_ID}/oauth2/token"
echo ""
echo "📝 環境変数の更新:"
echo "   OAUTH2_PROXY_OIDC_ISSUER_URL=http://cognito-local:9229/${USER_POOL_ID}"
echo ""
