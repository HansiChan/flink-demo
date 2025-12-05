SET 'execution.runtime-mode' = 'streaming';
SET 'table.dynamic-table-options.enabled' = 'true';
SET 'table.exec.sink.upsert-materialize' = 'NONE';
SET 'execution.checkpointing.interval' = '30s';

-- Register Paimon catalog on MinIO
CREATE CATALOG paimon WITH (
    'type' = 'paimon',
    'warehouse' = 's3://demo/',
    's3.endpoint' = 'http://minio:9000',
    's3.access-key' = 'minioadmin',
    's3.secret-key' = 'minioadmin',
    's3.path.style.access' = 'true'
);

USE CATALOG paimon;

CREATE DATABASE IF NOT EXISTS ods;
CREATE DATABASE IF NOT EXISTS dwd;

-- Read directly from Paimon catalog tables
-- Note: ods.ods_orders and ods.ods_customers should already exist from SeaTunnel sync

-- 10-minute windowed aggregation written to DWD layer
DROP TABLE IF EXISTS dwd.customer_order_metrics_10m;

CREATE TABLE IF NOT EXISTS dwd.customer_order_metrics_10m (
    window_start TIMESTAMP(3),
    window_end TIMESTAMP(3),
    dt DATE,
    customer_id INT,
    customer_name STRING,
    region STRING,
    order_cnt BIGINT,
    paid_cnt BIGINT,
    total_amount DECIMAL(18, 2),
    paid_amount DECIMAL(18, 2),
    last_update TIMESTAMP_LTZ(3),
    PRIMARY KEY (window_start, customer_id) NOT ENFORCED
) PARTITIONED BY (dt);

-- Enrich orders with customer info via temporal join, then window
INSERT INTO dwd.customer_order_metrics_10m
SELECT
    window_start,
    window_end,
    CAST(window_start AS DATE) AS dt,
    customer_id,
    MAX(customer_name) AS customer_name,
    MAX(region) AS region,
    COUNT(*) AS order_cnt,
    SUM(CASE WHEN status = 'paid' THEN 1 ELSE 0 END) AS paid_cnt,
    SUM(amount) AS total_amount,
    SUM(CASE WHEN status = 'paid' THEN amount ELSE 0 END) AS paid_amount,
    CURRENT_TIMESTAMP AS last_update
FROM (
    SELECT
        o.order_id,
        o.customer_id,
        o.amount,
        o.status,
        o.order_date,
        c.customer_name,
        c.region,
        TUMBLE_START(o.order_date, INTERVAL '10' MINUTES) AS window_start,
        TUMBLE_END(o.order_date, INTERVAL '10' MINUTES) AS window_end
    FROM ods.ods_orders AS o
    LEFT JOIN ods.ods_customers FOR SYSTEM_TIME AS OF o.`$rowtime` AS c
        ON o.customer_id = c.customer_id
)
GROUP BY window_start, window_end, customer_id;
