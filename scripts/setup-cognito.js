const AWS = require('aws-sdk');

// AWS設定（Moto用）
AWS.config.update({
  accessKeyId: 'testing',
  secretAccessKey: 'testing',
  region: 'us-east-1',
  endpoint: 'http://moto:5000',
  cognitoIdentityServiceProvider: {
    endpoint: 'http://moto:5000'
  }
});

const cognito = new AWS.CognitoIdentityServiceProvider();

async function setupCognito() {
  console.log('=== Cognito User Poolセットアップ開始 ===');
  
  try {
    // User Pool作成
    console.log('User Poolを作成中...');
    const userPoolParams = {
      PoolName: 'oauth-test-pool',
      Policies: {
        PasswordPolicy: {
          MinimumLength: 8,
          RequireUppercase: false,
          RequireLowercase: false,
          RequireNumbers: false,
          RequireSymbols: false
        }
      },
      AutoVerifiedAttributes: ['email'],
      UsernameAttributes: ['email'],
      Schema: [
        {
          AttributeDataType: 'String',
          Name: 'email',
          Required: true,
          Mutable: true
        },
        {
          AttributeDataType: 'String',
          Name: 'given_name',
          Required: false,
          Mutable: true
        },
        {
          AttributeDataType: 'String',
          Name: 'family_name',
          Required: false,
          Mutable: true
        }
      ]
    };

    const userPool = await cognito.createUserPool(userPoolParams).promise();
    const userPoolId = userPool.UserPool.Id;
    console.log(`User Pool作成完了: ${userPoolId}`);

    // User Pool Domain設定
    console.log('User Pool Domainを設定中...');
    const domainParams = {
      Domain: 'oauth-test-domain',
      UserPoolId: userPoolId
    };
    
    await cognito.createUserPoolDomain(domainParams).promise();
    console.log('User Pool Domain設定完了: oauth-test-domain');

    // User Pool Client作成
    console.log('User Pool Clientを作成中...');
    const clientParams = {
      UserPoolId: userPoolId,
      ClientName: 'oauth-test-client',
      GenerateSecret: true,
      CallbackURLs: ['http://localhost:9000/oauth2/callback'],
      LogoutURLs: ['http://localhost:9000/oauth2/sign_out'],
      AllowedOAuthFlows: ['code'],
      AllowedOAuthScopes: ['openid', 'email', 'profile'],
      AllowedOAuthFlowsUserPoolClient: true,
      SupportedIdentityProviders: ['COGNITO'],
      ExplicitAuthFlows: [
        'ALLOW_USER_PASSWORD_AUTH',
        'ALLOW_REFRESH_TOKEN_AUTH',
        'ALLOW_USER_SRP_AUTH'
      ]
    };

    const client = await cognito.createUserPoolClient(clientParams).promise();
    const clientId = client.UserPoolClient.ClientId;
    const clientSecret = client.UserPoolClient.ClientSecret;
    console.log(`User Pool Client作成完了: ${clientId}`);

    // テストユーザー作成
    console.log('テストユーザーを作成中...');
    const userParams = {
      UserPoolId: userPoolId,
      Username: 'testuser@example.com',
      UserAttributes: [
        { Name: 'email', Value: 'testuser@example.com' },
        { Name: 'given_name', Value: 'Test' },
        { Name: 'family_name', Value: 'User' },
        { Name: 'email_verified', Value: 'true' }
      ],
      TemporaryPassword: 'TempPass123!',
      MessageAction: 'SUPPRESS'
    };

    await cognito.adminCreateUser(userParams).promise();
    console.log('テストユーザー作成完了: testuser@example.com');

    // パスワード設定
    const passwordParams = {
      UserPoolId: userPoolId,
      Username: 'testuser@example.com',
      Password: 'TestPass123!',
      Permanent: true
    };

    await cognito.adminSetUserPassword(passwordParams).promise();
    console.log('テストユーザーパスワード設定完了');

    // 設定情報を出力
    console.log('\n=== Cognito設定情報 ===');
    console.log(`User Pool ID: ${userPoolId}`);
    console.log(`Client ID: ${clientId}`);
    console.log(`Client Secret: ${clientSecret}`);
    console.log(`Domain: oauth-test-domain.auth.us-east-1.amazoncognito.com`);
    console.log(`Authorization URL: http://localhost:5000/oauth-test-domain/oauth2/authorize`);
    console.log(`Token URL: http://localhost:5000/oauth-test-domain/oauth2/token`);
    console.log(`User Info URL: http://localhost:5000/oauth-test-domain/oauth2/userInfo`);
    console.log('\nテストユーザー:');
    console.log('Email: testuser@example.com');
    console.log('Password: TestPass123!');
    console.log('\n=== セットアップ完了 ===');

    // 環境変数用の出力
    console.log('\n=== .env設定用情報 ===');
    console.log(`OAUTH2_PROXY_CLIENT_ID=${clientId}`);
    console.log(`OAUTH2_PROXY_CLIENT_SECRET=${clientSecret}`);
    console.log(`OAUTH2_PROXY_OIDC_ISSUER_URL=http://localhost:5000/${userPoolId}`);
    console.log(`COGNITO_USER_POOL_ID=${userPoolId}`);
    console.log(`COGNITO_DOMAIN=oauth-test-domain`);

    return {
      userPoolId,
      clientId,
      clientSecret,
      domain: 'oauth-test-domain'
    };

  } catch (error) {
    console.error('Cognitoセットアップエラー:', error);
    throw error;
  }
}

// メイン実行
if (require.main === module) {
  setupCognito()
    .then((config) => {
      console.log('\nCognitoセットアップが正常に完了しました。');
      process.exit(0);
    })
    .catch((error) => {
      console.error('セットアップ失敗:', error);
      process.exit(1);
    });
}

module.exports = { setupCognito };