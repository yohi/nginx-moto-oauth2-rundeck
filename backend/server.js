const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const session = require('express-session');
const AWS = require('aws-sdk');
const { authenticateUser, getUserInfo, listUserPools, listUserPoolClients, USER_POOL_ID, CLIENT_ID } = require('./cognito-auth');

const app = express();
const PORT = process.env.PORT || 8080;

// AWSの設定（Moto用）
AWS.config.update({
  accessKeyId: process.env.AWS_ACCESS_KEY_ID || 'testing',
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || 'testing',
  region: process.env.AWS_DEFAULT_REGION || 'us-east-1',
  endpoint: process.env.AWS_ENDPOINT_URL || 'http://moto:5000',
  s3ForcePathStyle: true // Moto用の設定
});

// AWS サービスクライアントの初期化
const s3 = new AWS.S3();
const dynamodb = new AWS.DynamoDB();

// ミドルウェア設定
app.use(helmet({
  contentSecurityPolicy: false // テスト用に一時的に無効化
})); // セキュリティヘッダー
app.use(cors()); // CORS設定
app.use(morgan('combined')); // ログ出力
app.use(express.json()); // JSON解析
app.use(express.urlencoded({ extended: true })); // URL エンコード解析

// セッション設定
app.use(session({
  secret: process.env.SESSION_SECRET || 'cognito-oauth-session-secret',
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: false, // HTTP環境用（本番ではtrueに設定）
    httpOnly: true,
    maxAge: 24 * 60 * 60 * 1000 // 24時間
  }
}));

// 認証情報ヘッダー追加ミドルウェア
app.use((req, res, next) => {
  // セッション認証が有効な場合、Rundeckで使用するヘッダーを設定
  if (req.session.authenticated && req.session.user) {
    const user = req.session.user;

    // Rundeckで使用する認証ヘッダーを設定
    req.headers['x-auth-request-email'] = user.attributes?.email || 'unknown';
    req.headers['x-auth-request-user'] = user.attributes?.email || 'unknown';
    req.headers['x-auth-request-given-name'] = user.attributes?.given_name || 'User';
    req.headers['x-auth-request-family-name'] = user.attributes?.family_name || 'Name';
    req.headers['x-auth-request-roles'] = 'user,admin'; // デフォルトロール

    // レスポンスヘッダーにも設定（プロキシ用）
    res.set({
      'X-Auth-Request-Email': req.headers['x-auth-request-email'],
      'X-Auth-Request-User': req.headers['x-auth-request-user'],
      'X-Auth-Request-Given-Name': req.headers['x-auth-request-given-name'],
      'X-Auth-Request-Family-Name': req.headers['x-auth-request-family-name'],
      'X-Auth-Request-Roles': req.headers['x-auth-request-roles']
    });
  }

  console.log('=== 認証ヘッダー情報 ===');
  console.log('X-Auth-Request-User:', req.headers['x-auth-request-user']);
  console.log('X-Auth-Request-Email:', req.headers['x-auth-request-email']);
  console.log('X-Auth-Request-Access-Token:', req.headers['x-auth-request-access-token'] ? '***隠匿***' : 'なし');
  console.log('Session Authenticated:', !!req.session.authenticated);
  console.log('=======================');
  next();
});

// ルートエンドポイント
app.get('/', (req, res) => {
  const sessionUser = req.session.user;
  const headerUser = req.headers['x-auth-request-user'] || 'unknown';
  const headerEmail = req.headers['x-auth-request-email'] || 'unknown';

  const authenticated = req.session.authenticated || !!(headerUser && headerEmail && headerUser !== 'unknown');
  const user = sessionUser || { name: headerUser, email: headerEmail };

  res.json({
    message: 'OAuth認証環境のサンプルバックエンドアプリケーション',
    user: user,
    authenticated: authenticated,
    timestamp: new Date().toISOString(),
    oauth2_links: {
      login: '/oauth2/start',
      logout: '/oauth2/sign_out'
    },
    endpoints: {
      health: '/health',
      user: '/user',
      aws_status: '/aws/status',
      s3_demo: '/aws/s3',
      dynamodb_demo: '/aws/dynamodb'
    }
  });
});

// ヘルスチェックエンドポイント
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// ユーザー情報エンドポイント
app.get('/user', (req, res) => {
  const sessionUser = req.session.user;
  const headerUser = req.headers['x-auth-request-user'];
  const headerEmail = req.headers['x-auth-request-email'];

  const authenticated = req.session.authenticated || !!(headerUser && headerEmail && headerUser !== 'unknown');

  if (!authenticated) {
    return res.status(401).json({
      error: '認証が必要です',
      message: '有効な認証情報が見つかりません',
      oauth2_login: '/oauth2/start'
    });
  }

  const user = sessionUser || { name: headerUser, email: headerEmail };

  res.json({
    user: {
      ...user,
      authenticated_at: new Date().toISOString()
    },
    authentication_source: sessionUser ? 'session' : 'headers',
    session_active: !!req.session.authenticated,
    headers: {
      'x-auth-request-user': headerUser || 'セッション認証',
      'x-auth-request-email': headerEmail || 'セッション認証',
      'x-auth-request-access-token': req.headers['x-auth-request-access-token'] ? '***提供済み***' : '未提供'
    }
  });
});

// AWS接続状態確認エンドポイント
app.get('/aws/status', async (req, res) => {
  try {
    // S3サービスの確認
    const s3Response = await s3.listBuckets().promise();

    // DynamoDBサービスの確認
    const dynamoResponse = await dynamodb.listTables().promise();

    res.json({
      aws_status: 'connected',
      endpoint: process.env.AWS_ENDPOINT_URL || 'http://moto:5000',
      services: {
        s3: {
          status: 'available',
          buckets_count: s3Response.Buckets ? s3Response.Buckets.length : 0
        },
        dynamodb: {
          status: 'available',
          tables_count: dynamoResponse.TableNames ? dynamoResponse.TableNames.length : 0
        }
      },
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('AWS接続エラー:', error);
    res.status(500).json({
      aws_status: 'error',
      error: error.message,
      endpoint: process.env.AWS_ENDPOINT_URL || 'http://moto:5000'
    });
  }
});

// S3デモエンドポイント
app.get('/aws/s3', async (req, res) => {
  const bucketName = 'demo-bucket-' + Date.now();

  try {
    // バケット作成
    await s3.createBucket({ Bucket: bucketName }).promise();
    console.log(`S3バケット作成: ${bucketName}`);

    // テストオブジェクトの作成
    const testObject = {
      message: 'OAuth認証環境からのテストオブジェクト',
      user: req.headers['x-auth-request-user'] || 'unknown',
      timestamp: new Date().toISOString()
    };

    await s3.putObject({
      Bucket: bucketName,
      Key: 'test-object.json',
      Body: JSON.stringify(testObject, null, 2),
      ContentType: 'application/json'
    }).promise();

    // オブジェクト一覧取得
    const objects = await s3.listObjectsV2({ Bucket: bucketName }).promise();

    res.json({
      action: 'S3デモ実行完了',
      bucket: bucketName,
      objects: objects.Contents,
      test_object: testObject
    });

  } catch (error) {
    console.error('S3デモエラー:', error);
    res.status(500).json({
      error: 'S3デモの実行に失敗しました',
      details: error.message
    });
  }
});

// DynamoDBデモエンドポイント
app.get('/aws/dynamodb', async (req, res) => {
  const tableName = 'demo-table-' + Date.now();

  try {
    // テーブル作成
    const tableParams = {
      TableName: tableName,
      KeySchema: [
        { AttributeName: 'id', KeyType: 'HASH' }
      ],
      AttributeDefinitions: [
        { AttributeName: 'id', AttributeType: 'S' }
      ],
      BillingMode: 'PAY_PER_REQUEST'
    };

    await dynamodb.createTable(tableParams).promise();
    console.log(`DynamoDBテーブル作成: ${tableName}`);

    // 少し待機（テーブル作成完了を待つ）
    await new Promise(resolve => setTimeout(resolve, 1000));

    // DynamoDB DocumentClientでアイテム操作
    const docClient = new AWS.DynamoDB.DocumentClient();

    // テストアイテムの挿入
    const testItem = {
      id: 'test-id-' + Date.now(),
      message: 'OAuth認証環境からのテストアイテム',
      user: req.headers['x-auth-request-user'] || 'unknown',
      timestamp: new Date().toISOString()
    };

    await docClient.put({
      TableName: tableName,
      Item: testItem
    }).promise();

    // アイテム取得
    const result = await docClient.get({
      TableName: tableName,
      Key: { id: testItem.id }
    }).promise();

    res.json({
      action: 'DynamoDBデモ実行完了',
      table: tableName,
      inserted_item: testItem,
      retrieved_item: result.Item
    });

  } catch (error) {
    console.error('DynamoDBデモエラー:', error);
    res.status(500).json({
      error: 'DynamoDBデモの実行に失敗しました',
      details: error.message
    });
  }
});

// Cognito認証テストエンドポイント
app.post('/auth/login', async (req, res) => {
  const { username, password, oauth2_flow } = req.body;

  if (!username || !password) {
    return res.status(400).json({
      error: 'ユーザー名とパスワードが必要です',
      required: ['username', 'password']
    });
  }

  try {
    const result = await authenticateUser(username, password);

    if (result.success) {
      // アクセストークンがある場合、ユーザー情報も取得
      let userInfo = null;
      if (result.tokens && result.tokens.AccessToken) {
        try {
          userInfo = await getUserInfo(result.tokens.AccessToken);
        } catch (error) {
          console.warn('ユーザー情報取得失敗:', error.message);
        }
      }

      // OAuth2フローの場合、セッションに認証結果を保存
      if (oauth2_flow === 'true') {
        req.session.authResult = {
          tokens: result.tokens,
          userInfo: userInfo
        };

        // OAuth2 callbackにリダイレクト
        const state = req.session.oauth2State;
        res.json({
          success: true,
          message: 'OAuth2認証成功',
          redirect: `/oauth2/callback?code=mock_auth_code&state=${state}`
        });
      } else {
        // 通常のAPI認証レスポンス
        res.json({
          success: true,
          message: '認証成功',
          tokens: result.tokens,
          userInfo: userInfo,
          challengeName: result.challengeName
        });
      }
    } else {
      res.status(401).json({
        success: false,
        error: result.error
      });
    }

  } catch (error) {
    console.error('認証処理エラー:', error);
    res.status(500).json({
      error: '認証処理中にエラーが発生しました',
      details: error.message
    });
  }
});

// Cognito設定情報エンドポイント
app.get('/auth/config', async (req, res) => {
  try {
    const userPools = await listUserPools();
    const clients = await listUserPoolClients(USER_POOL_ID);

    res.json({
      cognito_config: {
        user_pool_id: USER_POOL_ID,
        client_id: CLIENT_ID,
        region: process.env.AWS_DEFAULT_REGION || 'us-east-1',
        endpoint: process.env.AWS_ENDPOINT_URL || 'http://moto:5000'
      },
      user_pools: userPools,
      clients: clients,
      test_user: {
        username: 'testuser@example.com',
        password: 'TestPass123!'
      }
    });
  } catch (error) {
    console.error('設定情報取得エラー:', error);
    res.status(500).json({
      error: '設定情報の取得に失敗しました',
      details: error.message
    });
  }
});

// OAuth2 Authorization Code Flow開始
app.get('/oauth2/start', (req, res) => {
  const state = Math.random().toString(36).substring(2, 15);
  const redirectUri = req.query.rd || '/';

  // セッションにstateとリダイレクト先を保存
  req.session.oauth2State = state;
  req.session.redirectAfterAuth = redirectUri;

  console.log('OAuth2認証開始 - State:', state, 'Redirect:', redirectUri);

  // 運用環境準拠：Cognito Hosted UIにリダイレクト
  // 本番環境では: https://your-cognito-domain.auth.region.amazoncognito.com/login
  res.redirect(`/cognito/hosted-ui?state=${state}&redirect_uri=${encodeURIComponent(redirectUri)}`);
});

// Cognito Hosted UI シミュレーション（運用環境準拠）
app.get('/cognito/hosted-ui', (req, res) => {
  const state = req.query.state;
  const redirectUri = req.query.redirect_uri;

  // 実際のCognito Hosted UIのデザインを模したページ
  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
        <title>Sign in - Amazon Cognito</title>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            body {
                font-family: "Amazon Ember", "Helvetica Neue", Roboto, Arial, sans-serif;
                background: #fafafa;
                margin: 0;
                padding: 20px;
                display: flex;
                justify-content: center;
                align-items: center;
                min-height: 100vh;
            }
            .auth-container {
                background: white;
                border-radius: 4px;
                box-shadow: 0 2px 4px rgba(0,0,0,0.1);
                padding: 40px;
                width: 100%;
                max-width: 400px;
            }
            .cognito-logo {
                text-align: center;
                margin-bottom: 30px;
            }
            .cognito-logo h2 {
                color: #232f3e;
                margin: 0;
                font-weight: 400;
            }
            .form-group {
                margin-bottom: 20px;
            }
            label {
                display: block;
                margin-bottom: 8px;
                color: #16191f;
                font-size: 14px;
                font-weight: 700;
            }
            input[type="email"], input[type="password"] {
                width: 100%;
                padding: 12px;
                border: 1px solid #d5d9d9;
                border-radius: 4px;
                font-size: 14px;
                box-sizing: border-box;
            }
            input[type="email"]:focus, input[type="password"]:focus {
                outline: none;
                border-color: #007eb9;
                box-shadow: 0 0 0 2px rgba(0, 126, 185, 0.2);
            }
            .sign-in-button {
                background: #ff9900;
                color: white;
                border: none;
                border-radius: 4px;
                padding: 12px;
                width: 100%;
                font-size: 14px;
                font-weight: 700;
                cursor: pointer;
                margin-top: 10px;
            }
            .sign-in-button:hover {
                background: #e88b00;
            }
            .divider {
                margin: 30px 0;
                text-align: center;
                position: relative;
            }
            .divider::before {
                content: '';
                position: absolute;
                top: 50%;
                left: 0;
                right: 0;
                height: 1px;
                background: #d5d9d9;
            }
            .divider span {
                background: white;
                padding: 0 15px;
                color: #687078;
                font-size: 12px;
            }
            .info {
                background: #d1ecf1;
                border: 1px solid #bee5eb;
                color: #0c5460;
                padding: 12px;
                border-radius: 4px;
                margin-bottom: 20px;
                font-size: 14px;
            }
            .aws-footer {
                text-align: center;
                margin-top: 30px;
                padding-top: 20px;
                border-top: 1px solid #d5d9d9;
                color: #687078;
                font-size: 12px;
            }
        </style>
    </head>
    <body>
        <div class="auth-container">
            <div class="cognito-logo">
                <h2>🔐 Amazon Cognito</h2>
                <p style="color: #687078; font-size: 14px; margin: 8px 0 0 0;">Sign in to your account</p>
            </div>

            <div class="info">
                <strong>Development Mode:</strong> Simulating Cognito Hosted UI<br>
                Production will use: <code>https://your-domain.auth.region.amazoncognito.com/login</code>
            </div>

            <form id="cognitoSignInForm">
                <div class="form-group">
                    <label for="username">Email address</label>
                    <input type="email" id="username" name="username" value="testuser@example.com" required>
                </div>

                <div class="form-group">
                    <label for="password">Password</label>
                    <input type="password" id="password" name="password" value="TestPass123!" required>
                </div>

                <button type="submit" class="sign-in-button">Sign in</button>
            </form>

            <div class="divider">
                <span>Powered by Amazon Cognito</span>
            </div>

            <div class="aws-footer">
                This is a simulated Cognito Hosted UI for development.<br>
                In production, users will be redirected to the real AWS Cognito service.
            </div>
        </div>

        <script>
            document.getElementById('cognitoSignInForm').addEventListener('submit', async (e) => {
                e.preventDefault();

                const username = document.getElementById('username').value;
                const password = document.getElementById('password').value;

                try {
                    // Cognito認証をシミュレート
                    const response = await fetch('/auth/login', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json',
                        },
                        body: JSON.stringify({
                            username,
                            password,
                            oauth2_flow: 'true'
                        })
                    });

                    const data = await response.json();

                    if (data.success && data.redirect) {
                        // OAuth2 callbackにリダイレクト（本来はCognitoがやる処理）
                        window.location.href = data.redirect;
                    } else {
                        alert('Sign in failed: ' + (data.error || 'Unknown error'));
                    }
                } catch (error) {
                    alert('Sign in error: ' + error.message);
                }
            });
        </script>
    </body>
    </html>
  `);
});

// OAuth2 Callback処理
app.get('/oauth2/callback', async (req, res) => {
  const { code, state } = req.query;

  console.log('OAuth2 Callback:', { code, state, sessionState: req.session.oauth2State });

  // State確認
  if (state && req.session.oauth2State && state !== req.session.oauth2State) {
    return res.status(400).json({
      error: 'Invalid state parameter',
      received: state,
      expected: req.session.oauth2State
    });
  }

  try {
    // Moto Cognitoの制限により、直接認証結果を処理
    if (req.session.authResult) {
      const authResult = req.session.authResult;

      // セッションに認証情報を保存
      req.session.authenticated = true;
      req.session.user = authResult.userInfo;
      req.session.tokens = authResult.tokens;

      // 認証後のリダイレクト先を取得
      const redirectTo = req.session.redirectAfterAuth || '/';

      // セッション情報をクリーンアップ
      delete req.session.oauth2State;
      delete req.session.authResult;
      delete req.session.redirectAfterAuth;

      console.log('OAuth2認証成功 - リダイレクト先:', redirectTo);
      res.redirect(redirectTo);
    } else {
      res.status(400).json({
        error: 'No authentication result found',
        message: 'Please complete the authentication process first'
      });
    }

  } catch (error) {
    console.error('OAuth2 Callback エラー:', error);
    res.status(500).json({
      error: 'OAuth2 callback processing failed',
      details: error.message
    });
  }
});

// OAuth2ログアウト
app.get('/oauth2/sign_out', (req, res) => {
  req.session.destroy((err) => {
    if (err) {
      console.error('セッション削除エラー:', err);
    }
    res.redirect('/');
  });
});

// 認証チェックエンドポイント（Nginx auth_request用）
app.get('/auth/verify', (req, res) => {
  if (req.session.authenticated && req.session.user) {
    const user = req.session.user;

    // 認証済みの場合、認証ヘッダーをレスポンスに設定
    res.set({
      'X-Auth-Request-Email': user.attributes?.email || 'unknown',
      'X-Auth-Request-User': user.attributes?.email || 'unknown',
      'X-Auth-Request-Given-Name': user.attributes?.given_name || 'User',
      'X-Auth-Request-Family-Name': user.attributes?.family_name || 'Name',
      'X-Auth-Request-Roles': 'user,admin'
    });

    res.status(200).json({
      authenticated: true,
      user: user.attributes?.email
    });
  } else {
    res.status(401).json({
      authenticated: false,
      login_url: '/oauth2/start'
    });
  }
});

// テスト用セッション設定エンドポイント
app.post('/auth/test-session', async (req, res) => {
  const { username, password } = req.body;

  if (!username || !password) {
    return res.status(400).json({
      error: 'ユーザー名とパスワードが必要です'
    });
  }

  try {
    const result = await authenticateUser(username, password);

    if (result.success) {
      // ユーザー情報を取得
      let userInfo = null;
      if (result.tokens && result.tokens.AccessToken) {
        try {
          userInfo = await getUserInfo(result.tokens.AccessToken);
        } catch (error) {
          console.warn('ユーザー情報取得失敗:', error.message);
        }
      }

      // セッションに認証情報を直接設定
      req.session.authenticated = true;
      req.session.user = userInfo;
      req.session.tokens = result.tokens;

      console.log('テストセッション設定完了:', userInfo);

      res.json({
        success: true,
        message: 'セッション認証完了',
        user: userInfo,
        session_id: req.session.id
      });
    } else {
      res.status(401).json({
        success: false,
        error: result.error
      });
    }

  } catch (error) {
    console.error('テストセッション設定エラー:', error);
    res.status(500).json({
      error: 'セッション設定中にエラーが発生しました',
      details: error.message
    });
  }
});

// Rundeck直接アクセス用セッション生成エンドポイント
app.post('/auth/rundeck-direct-access', async (req, res) => {
  if (!req.session.authenticated || !req.session.user) {
    return res.status(401).json({
      error: '認証が必要です',
      message: '先にOAuth2認証を完了してください'
    });
  }

  try {
    const user = req.session.user;

    // Rundeck用の認証トークン生成（簡易版）
    const authToken = Buffer.from(JSON.stringify({
      email: user.attributes.email,
      given_name: user.attributes.given_name,
      family_name: user.attributes.family_name,
      roles: ['user', 'admin'],
      timestamp: Date.now()
    })).toString('base64');

    res.json({
      success: true,
      message: 'Rundeck直接アクセス準備完了',
      user: {
        email: user.attributes.email,
        name: `${user.attributes.given_name} ${user.attributes.family_name}`
      },
      rundeck_direct_url: `http://localhost:4440/`,
      auth_token: authToken,
      instructions: [
        '1. 上記URLに直接アクセス',
        '2. RundeckでCookieベース認証を使用',
        '3. 認証情報は自動的に設定されます'
      ]
    });
  } catch (error) {
    console.error('Rundeck直接アクセス準備エラー:', error);
    res.status(500).json({
      error: 'Rundeck直接アクセス準備中にエラーが発生しました',
      details: error.message
    });
  }
});

// シンプルなログインフォーム（テスト用）
app.get('/auth/login-form', (req, res) => {
  const isOAuth2Flow = req.query.state && req.query.redirect_uri;
  const state = req.query.state || '';
  const redirectUri = req.query.redirect_uri || '';

  const html = `
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Cognito認証テスト</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 500px; margin: 50px auto; padding: 20px; }
        .form-group { margin-bottom: 15px; }
        label { display: block; margin-bottom: 5px; font-weight: bold; }
        input { width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px; }
        button { background: #007bff; color: white; padding: 10px 20px; border: none; border-radius: 4px; cursor: pointer; }
        button:hover { background: #0056b3; }
        .result { margin-top: 20px; padding: 10px; border-radius: 4px; }
        .success { background: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
        .error { background: #f8d7da; color: #721c24; border: 1px solid #f5c6cb; }
        .info { background: #d1ecf1; color: #0c5460; border: 1px solid #bee5eb; }
        pre { background: #f8f9fa; padding: 10px; border-radius: 4px; overflow-x: auto; }
    </style>
</head>
<body>
    <h1>Moto Cognito認証テスト</h1>

    <div class="info">
        <strong>テストユーザー:</strong><br>
        Email: testuser@example.com<br>
        Password: TestPass123!
        ${isOAuth2Flow ? '<br><br><strong>OAuth2認証フロー実行中</strong>' : ''}
    </div>

    <form id="loginForm">
        <div class="form-group">
            <label for="username">ユーザー名（Email）:</label>
            <input type="email" id="username" name="username" value="testuser@example.com" required>
        </div>

        <div class="form-group">
            <label for="password">パスワード:</label>
            <input type="password" id="password" name="password" value="TestPass123!" required>
        </div>

        <button type="submit">ログイン</button>
        <button type="button" onclick="directSessionLogin()" style="margin-left: 10px; background: #28a745;">直接セッション設定</button>
        <button type="button" onclick="rundeckLogin()" style="margin-left: 10px; background: #dc3545;">Rundeckログイン</button>
        <button type="button" onclick="rundeckDirectAccess()" style="margin-left: 10px; background: #6f42c1;">Rundeck直接アクセス</button>
    </form>

    <div id="result"></div>

    <hr>
    <h3>設定情報</h3>
    <button onclick="loadConfig()">Cognito設定を確認</button>
    <div id="config"></div>

    <hr>
    <h3>テスト機能</h3>
    <button onclick="testRundeckAccess()">Rundeckアクセステスト</button>
    <div id="testResult"></div>

    <script>
        const isOAuth2Flow = '${isOAuth2Flow}' === 'true';
        const oauth2State = '${state}';

        document.getElementById('loginForm').addEventListener('submit', async (e) => {
            e.preventDefault();

            const username = document.getElementById('username').value;
            const password = document.getElementById('password').value;
            const resultDiv = document.getElementById('result');

            resultDiv.innerHTML = '<div class="info">認証中...</div>';

            try {
                const requestBody = {
                    username,
                    password,
                    oauth2_flow: isOAuth2Flow ? 'true' : 'false'
                };

                const response = await fetch('/auth/login', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify(requestBody)
                });

                const data = await response.json();

                if (data.success) {
                    if (data.redirect && isOAuth2Flow) {
                        // OAuth2フローの場合はリダイレクト
                        resultDiv.innerHTML = '<div class="success">認証成功！リダイレクト中...</div>';
                        setTimeout(() => {
                            window.location.href = data.redirect;
                        }, 1000);
                    } else {
                        // 通常のAPI認証の場合
                        resultDiv.innerHTML = \`
                            <div class="success">
                                <strong>認証成功!</strong><br>
                                <pre>\${JSON.stringify(data, null, 2)}</pre>
                            </div>
                        \`;
                    }
                } else {
                    resultDiv.innerHTML = \`
                        <div class="error">
                            <strong>認証失敗:</strong> \${data.error}<br>
                            <pre>\${JSON.stringify(data, null, 2)}</pre>
                        </div>
                    \`;
                }
            } catch (error) {
                resultDiv.innerHTML = \`
                    <div class="error">
                        <strong>エラー:</strong> \${error.message}
                    </div>
                \`;
            }
        });

        async function loadConfig() {
            const configDiv = document.getElementById('config');
            configDiv.innerHTML = '<div class="info">設定情報を読み込み中...</div>';

            try {
                const response = await fetch('/auth/config');
                const data = await response.json();

                configDiv.innerHTML = \`
                    <div class="success">
                        <pre>\${JSON.stringify(data, null, 2)}</pre>
                    </div>
                \`;
            } catch (error) {
                configDiv.innerHTML = \`
                    <div class="error">
                        <strong>エラー:</strong> \${error.message}
                    </div>
                \`;
            }
        }

        // 直接セッション設定
        async function directSessionLogin() {
            const username = document.getElementById('username').value;
            const password = document.getElementById('password').value;
            const resultDiv = document.getElementById('result');

            resultDiv.innerHTML = '<div class="info">直接セッション設定中...</div>';

            try {
                const response = await fetch('/auth/test-session', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({ username, password })
                });

                const data = await response.json();

                if (data.success) {
                    resultDiv.innerHTML = \`
                        <div class="success">
                            <strong>セッション設定成功!</strong><br>
                            ユーザー: \${data.user.attributes?.email}<br>
                            セッションID: \${data.session_id}
                        </div>
                    \`;
                } else {
                    resultDiv.innerHTML = \`
                        <div class="error">
                            <strong>セッション設定失敗:</strong> \${data.error}
                        </div>
                    \`;
                }
            } catch (error) {
                resultDiv.innerHTML = \`
                    <div class="error">
                        <strong>エラー:</strong> \${error.message}
                    </div>
                \`;
            }
        }

        // Rundeckログイン
        async function rundeckLogin() {
            const username = document.getElementById('username').value;
            const password = document.getElementById('password').value;
            const resultDiv = document.getElementById('result');

            resultDiv.innerHTML = '<div class="info">Rundeckログイン中...認証してからRundeckに遷移します</div>';

            try {
                // 1. 認証実行
                const authResponse = await fetch('/auth/test-session', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({ username, password })
                });

                const authData = await authResponse.json();

                if (authData.success) {
                    resultDiv.innerHTML = \`
                        <div class="success">
                            <strong>認証成功!</strong><br>
                            ユーザー: \${authData.user.attributes?.email}<br>
                            Rundeckに遷移中...
                        </div>
                    \`;

                    // 2. 認証成功後、Rundeckに遷移
                    setTimeout(() => {
                        window.location.href = '/rundeck/';
                    }, 2000);
                } else {
                    resultDiv.innerHTML = \`
                        <div class="error">
                            <strong>認証失敗:</strong> \${authData.error}<br>
                            Rundeckにアクセスできません
                        </div>
                    \`;
                }
            } catch (error) {
                resultDiv.innerHTML = \`
                    <div class="error">
                        <strong>Rundeckログインエラー:</strong> \${error.message}
                    </div>
                \`;
            }
                }

        // Rundeck直接アクセス
        async function rundeckDirectAccess() {
            const username = document.getElementById('username').value;
            const password = document.getElementById('password').value;
            const resultDiv = document.getElementById('result');

            resultDiv.innerHTML = '<div class="info">Rundeck直接アクセス準備中...</div>';

            try {
                // 1. 認証実行
                const authResponse = await fetch('/auth/test-session', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({ username, password })
                });

                const authData = await authResponse.json();

                if (authData.success) {
                    // 2. Rundeck直接アクセス準備
                    const directResponse = await fetch('/auth/rundeck-direct-access', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json',
                        }
                    });

                    const directData = await directResponse.json();

                    if (directData.success) {
                        resultDiv.innerHTML = \`
                            <div class="success">
                                <strong>Rundeck直接アクセス準備完了!</strong><br>
                                ユーザー: \${directData.user.email}<br>
                                <br>
                                <a href="\${directData.rundeck_direct_url}" target="_blank"
                                   style="color: white; background: #6f42c1; padding: 10px 20px; text-decoration: none; border-radius: 4px; display: inline-block;">
                                   Rundeckに直接アクセス (新しいタブ)
                                </a>
                                <br><br>
                                <small>注意: この方法では<strong>Nginxをバイパス</strong>してRundeck(localhost:4440)に直接アクセスします</small>
                            </div>
                        \`;
                    } else {
                        resultDiv.innerHTML = \`
                            <div class="error">
                                <strong>直接アクセス準備失敗:</strong> \${directData.error}
                            </div>
                        \`;
                    }
                } else {
                    resultDiv.innerHTML = \`
                        <div class="error">
                            <strong>認証失敗:</strong> \${authData.error}<br>
                            Rundeck直接アクセスを準備できません
                        </div>
                    \`;
                }
            } catch (error) {
                resultDiv.innerHTML = \`
                    <div class="error">
                        <strong>エラー:</strong> \${error.message}
                    </div>
                \`;
            }
        }

        // Rundeckアクセステスト
        async function testRundeckAccess() {
            const testResultDiv = document.getElementById('testResult');
            testResultDiv.innerHTML = '<div class="info">Rundeckアクセステスト中...</div>';

            try {
                // 認証状態確認
                const authResponse = await fetch('/user');
                const authData = await authResponse.json();

                if (authData.authenticated) {
                    testResultDiv.innerHTML = \`
                        <div class="success">
                            <strong>認証状態:</strong> OK<br>
                            <strong>ユーザー:</strong> \${authData.user.attributes?.email}<br>
                            <a href="/rundeck/" target="_blank" style="color: white; background: #007bff; padding: 5px 10px; text-decoration: none; border-radius: 3px;">Rundeckを開く</a>
                        </div>
                    \`;
                } else {
                    testResultDiv.innerHTML = \`
                        <div class="error">
                            <strong>認証状態:</strong> 未認証<br>
                            先にログインまたは直接セッション設定を実行してください
                        </div>
                    \`;
                }
            } catch (error) {
                testResultDiv.innerHTML = \`
                    <div class="error">
                        <strong>テストエラー:</strong> \${error.message}
                    </div>
                \`;
            }
        }
    </script>
</body>
</html>
  `;

  res.send(html);
});

// エラーハンドリングミドルウェア
app.use((err, req, res, next) => {
  console.error('アプリケーションエラー:', err);
  res.status(500).json({
    error: 'サーバー内部エラー',
    message: err.message
  });
});

// 404ハンドラー
app.use((req, res) => {
  res.status(404).json({
    error: 'エンドポイントが見つかりません',
    path: req.path,
    method: req.method
  });
});

// サーバー起動
app.listen(PORT, () => {
  console.log(`===========================================`);
  console.log(`OAuth認証バックエンドサーバー起動`);
  console.log(`ポート: ${PORT}`);
  console.log(`AWS エンドポイント: ${process.env.AWS_ENDPOINT_URL || 'http://moto:5000'}`);
  console.log(`開始時間: ${new Date().toISOString()}`);
  console.log(`===========================================`);
});

// プロセス終了時の処理
process.on('SIGTERM', () => {
  console.log('SIGTERM受信。サーバーを正常終了します...');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT受信。サーバーを正常終了します...');
  process.exit(0);
});
