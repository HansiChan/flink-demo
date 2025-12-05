-- ========================================
-- Flink SQL: ODS to DWD Real-time Aggregation
-- Purpose: 10-minute window aggregation from Paimon ODS to DWD
-- ========================================

SET 'execution.runtime-mode' = 'streaming';
SET 'execution.checkpointing.interval' = '1min';
SET 'table.exec.state.ttl' = '1h';

-- Create Paimon catalog
CREATE CATALOG paimon WITH (
    'type' = 'paimon',
    'warehouse' = 's3://demo/',
    's3.endpoint' = 'http://minio:9000',
    's3.access-key' = 'minioadmin',
    's3.secret-key' = 'minioadmin',
    's3.path.style.access' = 'true'
);

USE CATALOG paimon;

-- Ensure databases exist
CREATE DATABASE IF NOT EXISTS ods;
CREATE DATABASE IF NOT EXISTS dwd;

-- Create temporary table to add watermark on top of Paimon table
CREATE TEMPORARY TABLE ods_orders_with_watermark (
    order_id INT,
    customer_id INT,
    order_date TIMESTAMP(3),
    amount DECIMAL(10, 2),
    status STRING,
    created_at TIMESTAMP(3),
    WATERMARK FOR order_date AS order_date - INTERVAL '5' SECOND
) WITH (
    'connector' = 'paimon',
    'warehouse' = 's3://demo/',
    'database' = 'ods',
    'table' = 'ods_orders',
    's3.endpoint' = 'http://minio:9000',
    's3.access-key' = 'minioadmin',
    's3.secret-key' = 'minioadmin',
    's3.path.style.access' = 'true'
);

-- Create DWD aggregation table
CREATE TABLE IF NOT EXISTS dwd.order_metrics_10m (
    window_start TIMESTAMP(3),
    window_end TIMESTAMP(3),
    customer_id INT,
    customer_name STRING,
    region STRING,
    order_count BIGINT,
    paid_order_count BIGINT,
    total_amount DECIMAL(18, 2),
    paid_amount DECIMAL(18, 2),
    dt STRING,
    PRIMARY KEY (window_start, customer_id) NOT ENFORCED
) PARTITIONED BY (dt) WITH (
    'bucket' = '2'
);

-- Insert aggregation result
INSERT INTO dwd.order_metrics_10m
SELECT
    TUMBLE_START(o.order_date, INTERVAL '10' MINUTES) AS window_start,
    TUMBLE_END(o.order_date, INTERVAL '10' MINUTES) AS window_end,
    o.customer_id,
    MAX(c.customer_name) AS customer_name,
    MAX(c.region) AS region,
    COUNT(*) AS order_count,
    COUNT(CASE WHEN o.status = 'paid' THEN 1 END) AS paid_order_count,
    SUM(o.amount) AS total_amount,
    SUM(CASE WHEN o.status = 'paid' THEN o.amount ELSE 0 END) AS paid_amount,
    DATE_FORMAT(TUMBLE_START(o.order_date, INTERVAL '10' MINUTES), 'yyyy-MM-dd') AS dt
FROM ods_orders_with_watermark AS o
JOIN ods.ods_customers AS c
    ON o.customer_id = c.customer_id
GROUP BY
    TUMBLE(o.order_date, INTERVAL '10' MINUTES),
    o.customer_id;
