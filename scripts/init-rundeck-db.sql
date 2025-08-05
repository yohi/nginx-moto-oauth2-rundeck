-- Rundeck PostgreSQL Database Initialization Script
-- Quartz Scheduler用のテーブル作成

-- Quartz Schedulerテーブル作成
-- RundeckのHA構成では自動的にテーブルが作成されるため、
-- このスクリプトは必要に応じて使用

-- データベース文字エンコーディング確認
SELECT current_setting('server_encoding');

-- Rundeck用ユーザーの権限確認
SELECT
    r.rolname,
    r.rolsuper,
    r.rolinherit,
    r.rolcreaterole,
    r.rolcreatedb,
    r.rolcanlogin,
    r.rolconnlimit,
    r.rolvaliduntil,
    ARRAY(SELECT b.rolname
          FROM pg_catalog.pg_auth_members m
          JOIN pg_catalog.pg_roles b ON (m.roleid = b.oid)
          WHERE m.member = r.oid) as memberof
FROM pg_catalog.pg_roles r
WHERE r.rolname = 'rundeck';

-- 接続プール設定の確認用クエリ
SELECT name, setting, unit, context
FROM pg_settings
WHERE name IN ('max_connections', 'shared_buffers', 'effective_cache_size');
