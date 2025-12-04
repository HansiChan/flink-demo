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

INSERT INTO dwd.customer_order_metrics_10m
SELECT
    window_start,
    window_end,
    CAST(window_start AS DATE) AS dt,
    customer_id,
    ANY_VALUE(customer_name) AS customer_name,
    ANY_VALUE(region) AS region,
    COUNT(*) AS order_cnt,
    SUM(CASE WHEN status = 'paid' THEN 1 ELSE 0 END) AS paid_cnt,
    SUM(amount) AS total_amount,
    SUM(CASE WHEN status = 'paid' THEN amount ELSE 0 END) AS paid_amount,
    CURRENT_TIMESTAMP AS last_update
FROM TABLE(
    TUMBLE(
        TABLE (
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
            ON o.customer_id = c.customer_id
        ),
        DESCRIPTOR(order_ts),
        INTERVAL '10' MINUTES
    )
)
GROUP BY window_start, window_end, customer_id;
