const AWS = require('aws-sdk');

// Cognito設定
const cognito = new AWS.CognitoIdentityServiceProvider({
  endpoint: process.env.AWS_ENDPOINT_URL || 'http://moto:5000',
  region: process.env.AWS_DEFAULT_REGION || 'us-east-1'
});

const USER_POOL_ID = process.env.COGNITO_USER_POOL_ID || 'local_6y3X7A8s';
const CLIENT_ID = process.env.COGNITO_CLIENT_ID || '6ukqb2z8xv0fd4p2ar2gp3sjl';

// シンプルなCognito認証ハンドラー
async function authenticateUser(username, password) {
  try {
    console.log(`認証試行: ${username}`);

    const params = {
      AuthFlow: 'USER_PASSWORD_AUTH',
      ClientId: CLIENT_ID,
      AuthParameters: {
        USERNAME: username,
        PASSWORD: password
      }
    };

    const result = await cognito.initiateAuth(params).promise();
    console.log('認証成功:', result.AuthenticationResult ? 'トークン取得' : '追加認証が必要');

    return {
      success: true,
      tokens: result.AuthenticationResult,
      challengeName: result.ChallengeName,
      session: result.Session
    };

  } catch (error) {
    console.error('認証エラー:', error.message);
    return {
      success: false,
      error: error.message
    };
  }
}

// ユーザー情報取得
async function getUserInfo(accessToken) {
  try {
    const params = {
      AccessToken: accessToken
    };

    const result = await cognito.getUser(params).promise();

    const userInfo = {
      username: result.Username,
      attributes: {}
    };

    // 属性を解析
    result.UserAttributes.forEach(attr => {
      userInfo.attributes[attr.Name] = attr.Value;
    });

    return userInfo;

  } catch (error) {
    console.error('ユーザー情報取得エラー:', error.message);
    throw error;
  }
}

// Cognito User Pool一覧取得（テスト用）
async function listUserPools() {
  try {
    const result = await cognito.listUserPools({ MaxResults: 10 }).promise();
    return result.UserPools;
  } catch (error) {
    console.error('User Pool一覧取得エラー:', error.message);
    return [];
  }
}

// User Pool Client一覧取得（テスト用）
async function listUserPoolClients(userPoolId) {
  try {
    const result = await cognito.listUserPoolClients({
      UserPoolId: userPoolId,
      MaxResults: 10
    }).promise();
    return result.UserPoolClients;
  } catch (error) {
    console.error('User Pool Client一覧取得エラー:', error.message);
    return [];
  }
}

module.exports = {
  authenticateUser,
  getUserInfo,
  listUserPools,
  listUserPoolClients,
  USER_POOL_ID,
  CLIENT_ID
};
