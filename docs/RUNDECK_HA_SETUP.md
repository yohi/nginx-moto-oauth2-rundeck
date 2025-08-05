# Rundeck HA (Active/Standby) 構成ガイド

## 概要

本ドキュメントでは、RundeckのActive/Standby構成を実装した高可用性システムの設定と運用について説明します。

## アーキテクチャ

```
[ Internet ]
     ↓ (OAuth2認証)
[ Nginx Load Balancer ]
     ↓ (認証済み)
[ Rundeck Active ] ← → [ Rundeck Standby ]
     ↓                      ↓
[ PostgreSQL Database (共有) ]
[ Shared File System (共有) ]
```

## 構成要素

### 1. Rundeck HA クラスター
- **rundeck-active**: メインのActiveノード (ポート: 4440)
- **rundeck-standby**: StandbyノードBackup (ポート: 4441)
- **rundeck-postgres**: 共有PostgreSQLデータベース

### 2. Load Balancer設定 (Nginx)
- Activeノード優先のフェイルオーバー
- ヘルスチェックによる自動切り替え
- セッション持続性の確保

### 3. 共有リソース
- PostgreSQLデータベース (クラスタ共有)
- ファイルシステム (rundeck-shared-data volume)

## 起動手順

### 1. 環境変数設定
必要な環境変数が設定されていることを確認:
```bash
# .env ファイル参照
source .env
```

### 2. システム起動
```bash
# 全サービス起動
docker-compose up -d

# Rundeck HA関連のみ起動
docker-compose up -d rundeck-postgres rundeck-active rundeck-standby
```

### 3. 起動確認
```bash
# ヘルスチェックスクリプト実行
./scripts/rundeck-ha-check.sh
```

## 運用・監視

### 1. ステータス確認
```bash
# HAステータス確認
./scripts/rundeck-failover.sh status

# 個別コンテナ確認
docker-compose ps rundeck-active rundeck-standby rundeck-postgres
```

### 2. ログ確認
```bash
# Active node ログ
docker-compose logs -f rundeck-active

# Standby node ログ
docker-compose logs -f rundeck-standby

# PostgreSQL ログ
docker-compose logs -f rundeck-postgres
```

### 3. 手動フェイルオーバー
```bash
# Active -> Standby 切り替え
./scripts/rundeck-failover.sh active-to-standby

# Standby -> Active 切り替え
./scripts/rundeck-failover.sh standby-to-active
```

## フェイルオーバー仕様

### 自動フェイルオーバー
- Nginxがrundeckの/healthエンドポイントを監視
- 3回連続で失敗（fail_timeout=30s）でバックアップに切り替え
- Activeノード復旧時は自動的に戻る

### 手動フェイルオーバー
- メンテナンス時の計画的切り替え
- 緊急時の強制切り替え
- スクリプトによる安全な切り替え

## データ保護

### 1. データベースバックアップ
```bash
# PostgreSQL バックアップ
docker-compose exec rundeck-postgres pg_dump -U rundeck rundeck > backup_$(date +%Y%m%d).sql
```

### 2. 設定ファイルバックアップ
```bash
# Rundeck設定のバックアップ
tar -czf rundeck_config_backup_$(date +%Y%m%d).tar.gz rundeck/config/
```

## トラブルシューティング

### 1. Activeノードが起動しない
```bash
# ログ確認
docker-compose logs rundeck-active

# PostgreSQL接続確認
docker-compose exec rundeck-postgres pg_isready -U rundeck

# 設定ファイル確認
docker-compose exec rundeck-active cat /home/rundeck/server/config/rundeck-config.properties
```

### 2. Standbyノードが同期しない
```bash
# クラスター状態確認
docker-compose exec rundeck-postgres psql -U rundeck -d rundeck -c "SELECT * FROM qrtz_scheduler_state;"

# Quartz設定確認
grep -i quartz rundeck/config/rundeck-config.properties
```

### 3. Nginxロードバランサーエラー
```bash
# Nginx設定テスト
docker-compose exec nginx nginx -t

# upstream状態確認
curl -I http://localhost:9000/rundeck/
```

## セキュリティ考慮事項

### 1. データベースセキュリティ
- PostgreSQL認証情報の環境変数化
- ネットワークアクセス制限
- 暗号化通信（本番環境）

### 2. OAuth2統合
- 認証ヘッダーの検証
- HTTPS強制（本番環境）
- セッションセキュリティ

## パフォーマンス最適化

### 1. データベース最適化
```sql
-- PostgreSQL統計情報更新
ANALYZE;

-- インデックス確認
SELECT tablename, indexname FROM pg_indexes WHERE schemaname = 'public';
```

### 2. Java heap設定
```bash
# Rundeck Java設定 (必要に応じて環境変数追加)
RUNDECK_JVM_OPTS="-Xmx2g -Xms1g"
```

## 設定ファイル

### 重要な設定ファイル
- `docker-compose.yml`: サービス定義
- `nginx/nginx.conf`: ロードバランサー設定
- `rundeck/config/rundeck-config.properties`: Rundeck HA設定

### 監視スクリプト
- `scripts/rundeck-ha-check.sh`: ヘルスチェック
- `scripts/rundeck-failover.sh`: フェイルオーバー管理

## 本番環境への展開

### 1. 環境固有設定
- SSL証明書設定
- ドメイン名設定
- リソース制限設定

### 2. 監視・アラート
- Prometheusメトリクス収集
- Grafanaダッシュボード
- アラートマネージャー設定

---

**注意**: 本番環境では適切なリソース制限、セキュリティ設定、バックアップ戦略を実装してください。
