# Node.js 18 Alpine ベースイメージを使用
FROM node:18-alpine

# 作業ディレクトリを設定
WORKDIR /app

# パッケージファイルをコピー
COPY package*.json ./

# 依存関係をインストール
RUN npm install --omit=dev

# アプリケーションコードをコピー
COPY . .

# 非rootユーザーを作成
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# アプリケーションファイルの所有権を変更
RUN chown -R nodejs:nodejs /app
USER nodejs

# ポート8080を公開
EXPOSE 8080

# ヘルスチェック設定
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD node -e "const http = require('http'); const options = { host: 'localhost', port: 8080, path: '/health', timeout: 5000 }; const request = http.get(options, (res) => { if (res.statusCode === 200) { process.exit(0); } else { process.exit(1); } }); request.on('error', () => process.exit(1)); request.on('timeout', () => process.exit(1));"

# アプリケーションを起動
CMD ["npm", "start"]