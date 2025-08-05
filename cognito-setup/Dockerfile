FROM node:18-alpine

WORKDIR /app

# AWS SDKをインストール
RUN npm install aws-sdk

# セットアップスクリプトをコピー
COPY scripts/setup-cognito.js ./setup-cognito.js

# スクリプトを実行
CMD ["node", "setup-cognito.js"]