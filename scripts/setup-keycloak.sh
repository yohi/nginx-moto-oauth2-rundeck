#!/bin/bash

# Keycloak自動設定スクリプト
# Realmとクライアント設定を自動化

KEYCLOAK_HOST="localhost:8080"
ADMIN_USER="admin"
ADMIN_PASSWORD="admin123"
REALM_NAME="rundeck"
CLIENT_ID="rundeck-client"
CLIENT_SECRET="rundeck-secret-key"

echo "🔧 Keycloak設定を開始します..."

# Keycloakの起動を待機
echo "⏳ Keycloakの起動を待機中..."
until curl -f "http://${KEYCLOAK_HOST}/realms/master" > /dev/null 2>&1; do
    echo "   Keycloakの起動を待機中..."
    sleep 5
done

echo "✅ Keycloakが起動しました"

# 管理者トークンを取得
echo "🔑 管理者トークンを取得中..."
ADMIN_TOKEN=$(curl -s -X POST "http://${KEYCLOAK_HOST}/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=${ADMIN_USER}" \
    -d "password=${ADMIN_PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" | jq -r '.access_token')

if [ "$ADMIN_TOKEN" = "null" ] || [ -z "$ADMIN_TOKEN" ]; then
    echo "❌ 管理者トークンの取得に失敗しました"
    exit 1
fi

echo "✅ 管理者トークンを取得しました"

# Rundeck用Realmを作成
echo "🏢 Rundeck用Realmを作成中..."
REALM_RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null -X POST "http://${KEYCLOAK_HOST}/admin/realms" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "realm": "'${REALM_NAME}'",
        "enabled": true,
        "displayName": "Rundeck Realm",
        "loginWithEmailAllowed": true,
        "registrationAllowed": false,
        "emailVerificationEnabled": false,
        "sslRequired": "none"
    }')

if [ "$REALM_RESPONSE" = "201" ] || [ "$REALM_RESPONSE" = "409" ]; then
    echo "✅ Rundeck Realmが作成されました"
else
    echo "⚠️  Rundeck Realm作成レスポンス: $REALM_RESPONSE"
fi

# OAuth2クライアントを作成
echo "📱 OAuth2クライアントを作成中..."
CLIENT_RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null -X POST "http://${KEYCLOAK_HOST}/admin/realms/${REALM_NAME}/clients" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "clientId": "'${CLIENT_ID}'",
        "enabled": true,
        "clientAuthenticatorType": "client-secret",
        "secret": "'${CLIENT_SECRET}'",
        "standardFlowEnabled": true,
        "implicitFlowEnabled": false,
        "directAccessGrantsEnabled": true,
        "serviceAccountsEnabled": false,
        "publicClient": false,
        "protocol": "openid-connect",
        "redirectUris": [
            "http://localhost:9000/oauth2/callback",
            "http://localhost:9000/*"
        ],
        "webOrigins": [
            "http://localhost:9000"
        ],
        "attributes": {
            "access.token.lifespan": "300",
            "client.session.idle.timeout": "1800",
            "client.session.max.lifespan": "3600"
        }
    }')

if [ "$CLIENT_RESPONSE" = "201" ] || [ "$CLIENT_RESPONSE" = "409" ]; then
    echo "✅ OAuth2クライアントが作成されました"
else
    echo "⚠️  OAuth2クライアント作成レスポンス: $CLIENT_RESPONSE"
fi

# テストユーザーを作成
echo "👤 テストユーザーを作成中..."
USER_RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null -X POST "http://${KEYCLOAK_HOST}/admin/realms/${REALM_NAME}/users" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "username": "admin",
        "enabled": true,
        "emailVerified": true,
        "firstName": "Admin",
        "lastName": "User",
        "email": "admin@example.com",
        "credentials": [{
            "type": "password",
            "value": "admin123",
            "temporary": false
        }]
    }')

if [ "$USER_RESPONSE" = "201" ] || [ "$USER_RESPONSE" = "409" ]; then
    echo "✅ テストユーザーが作成されました"
else
    echo "⚠️  テストユーザー作成レスポンス: $USER_RESPONSE"
fi

echo ""
echo "🎉 Keycloak設定が完了しました！"
echo ""
echo "📋 設定情報:"
echo "   • Keycloak管理画面: http://localhost:8080"
echo "   • 管理者ユーザー: ${ADMIN_USER}"
echo "   • 管理者パスワード: ${ADMIN_PASSWORD}"
echo "   • Realm名: ${REALM_NAME}"
echo "   • クライアントID: ${CLIENT_ID}"
echo "   • クライアントシークレット: ${CLIENT_SECRET}"
echo "   • テストユーザー: admin / admin123"
echo ""
echo "🔗 OIDC エンドポイント:"
echo "   • Discovery: http://localhost:8080/realms/${REALM_NAME}/.well-known/openid-configuration"
echo "   • JWKS: http://localhost:8080/realms/${REALM_NAME}/protocol/openid-connect/certs"
echo ""