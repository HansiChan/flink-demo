SET 'execution.runtime-mode' = 'streaming';
SET 'table.dynamic-table-options.enabled' = 'true';
SET 'table.exec.sink.upsert-materialize' = 'NONE';

-- Register Paimon catalog on MinIO
CREATE CATALOG paimon WITH (
    'type' = 'paimon',
    'warehouse' = 's3://demo/',
    's3.access-key' = 'minioadmin',
    's3.secret-key' = 'minioadmin',
    's3.endpoint' = 'http://minio:9000',
    's3.path.style.access' = 'true'
);

USE CATALOG paimon;

CREATE DATABASE IF NOT EXISTS ods;
CREATE DATABASE IF NOT EXISTS dwd;

-- Stream from ods_orders with event-time watermark and proc time for temporal lookup
CREATE TEMPORARY TABLE ods_orders_stream (
    order_id INT,
    customer_id INT,
    order_date TIMESTAMP(3),
    amount DECIMAL(10, 2),
    status STRING,
    created_at TIMESTAMP(3),
    order_ts AS order_date,
    proctime AS PROCTIME(),
    WATERMARK FOR order_ts AS order_ts - INTERVAL '30' SECOND
) WITH (
    'connector' = 'paimon',
    'warehouse' = 's3://demo/',
    'database' = 'ods',
    'table' = 'ods_orders',
    'scan.mode' = 'latest',
    'monitor-interval' = '5 s'
);

-- Customer dimension as lookup table; primary key enables temporal join
CREATE TEMPORARY TABLE ods_customers_dim (
    customer_id INT,
    customer_name STRING,
    region STRING,
    created_at TIMESTAMP(3),
    PRIMARY KEY (customer_id) NOT ENFORCED
) WITH (
    'connector' = 'paimon',
    'warehouse' = 's3://demo/',
    'database' = 'ods',
    'table' = 'ods_customers',
    'scan.mode' = 'latest',
    'monitor-interval' = '5 s',
    'lookup.cache.max-rows' = '10000',
    'lookup.cache.ttl' = '10 min'
);

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

-- Enrich orders with customer info via temporal join (materialized as a view for windowing)
CREATE OR REPLACE TEMPORARY VIEW ods_orders_enriched AS
SELECT
    o.order_id,
    o.customer_id,
    o.amount,
    o.status,
    o.order_ts,
    c.customer_name,
    c.region
FROM ods_orders_stream AS o
LEFT JOIN ods_customers_dim FOR SYSTEM_TIME AS OF o.proctime AS c
ON o.customer_id = c.customer_id;

INSERT INTO dwd.customer_order_metrics_10m
SELECT
    tw.window_start,
    tw.window_end,
    CAST(tw.window_start AS DATE) AS dt,
    tw.customer_id,
    ANY_VALUE(tw.customer_name) AS customer_name,
    ANY_VALUE(tw.region) AS region,
    COUNT(*) AS order_cnt,
    SUM(CASE WHEN tw.status = 'paid' THEN 1 ELSE 0 END) AS paid_cnt,
    SUM(tw.amount) AS total_amount,
    SUM(CASE WHEN tw.status = 'paid' THEN tw.amount ELSE 0 END) AS paid_amount,
    CURRENT_TIMESTAMP AS last_update
FROM TABLE(
    TUMBLE(
        TABLE ods_orders_enriched,
        DESCRIPTOR(order_ts),
        INTERVAL '10' MINUTES
    )
) AS tw (
    order_id,
    customer_id,
    amount,
    status,
    order_ts,
    customer_name,
    region,
    window_start,
    window_end,
    window_time
)
GROUP BY tw.window_start, tw.window_end, tw.customer_id;
