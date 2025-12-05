-- Flink SQL任务：统计每个客户每小时的订单总量和订单总金额
SET 'execution.runtime-mode' = 'streaming';
SET 'table.dynamic-table-options.enabled' = 'true';
SET 'table.exec.sink.upsert-materialize' = 'NONE';
SET 'pipeline.name' = 'customer_hourly_order_metrics';

-- 创建Paimon catalog
CREATE CATALOG paimon WITH (
    'type' = 'paimon',
    'warehouse' = 's3://demo/',
    's3.access-key' = 'minioadmin',
    's3.secret-key' = 'minioadmin',
    's3.endpoint' = 'http://minio:9000',
    's3.path.style.access' = 'true'
);

USE CATALOG paimon;

-- 如果dwd数据库不存在则创建
CREATE DATABASE IF NOT EXISTS dwd;

-- 创建dwd层的聚合结果表
CREATE TABLE IF NOT EXISTS dwd.dwd_customer_order_hourly_metrics (
    customer_id INT,
    customer_name STRING,
    region STRING,
    window_start TIMESTAMP(3),
    window_end TIMESTAMP(3),
    order_count BIGINT,
    total_amount DECIMAL(20,2),
    PRIMARY KEY (customer_id, window_start) NOT ENFORCED
) WITH (
    'bucket' = '2',
    'changelog-producer' = 'input'
);

-- 执行聚合任务：统计每个客户每小时的订单指标
INSERT INTO dwd.dwd_customer_order_hourly_metrics
SELECT
    c.customer_id,
    c.customer_name,
    c.region,
    TUMBLE_START(o.order_date, INTERVAL '1' HOUR) AS window_start,
    TUMBLE_END(o.order_date, INTERVAL '1' HOUR) AS window_end,
    COUNT(o.order_id) AS order_count,
    SUM(o.amount) AS total_amount
FROM ods.ods_orders o
INNER JOIN ods.ods_customers c
    ON o.customer_id = c.customer_id
GROUP BY
    c.customer_id,
    c.customer_name,
    c.region,
    TUMBLE(o.order_date, INTERVAL '1' HOUR);
