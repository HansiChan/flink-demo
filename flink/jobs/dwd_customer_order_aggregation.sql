-- Flink SQL Job: dwd_customer_order_aggregation
-- Description: Aggregates customer orders from ODS to DWD layer.

-- ================================ ONE-TIME SETUP ==================================
-- IMPORTANT: Before running the INSERT job, you must define a watermark for the
-- 'ods.ods_orders' table. This is required for the time-based temporal join.
--
-- Connect to the Flink SQL client and run the following command ONCE:
/*

ALTER TABLE ods.ods_orders SET (
    'scan.watermark.definition' = '`order_date` - INTERVAL ''1'' SECOND'
);

*/
-- After this setup, you can run the INSERT INTO statement below as a long-running job.
-- ====================================================================================


-- ############## 1. Catalog and Environment Setup ##############
-- Create a Paimon catalog to connect to the data lakehouse on MinIO.
-- The warehouse path 's3a://demo/' assumes Paimon data is in a bucket named 'demo'.
CREATE CATALOG paimon WITH (
    'type' = 'paimon',
    'warehouse' = 's3a://demo/',
    's3.endpoint' = 'http://minio:9000',
    's3.access-key' = 'minioadmin',
    's3.secret-key' = 'minioadmin',
    's3.path.style.access' = 'true'
);

-- Switch to the Paimon catalog for the current session.
USE CATALOG paimon;

-- The DWD database and target table should be created during the setup.
-- You can also run these commands in the SQL client if needed.
CREATE DATABASE IF NOT EXISTS dwd;

CREATE TABLE IF NOT EXISTS dwd.customer_order_aggregation (
    customer_id BIGINT,
    customer_name STRING,
    region STRING,
    total_amount DECIMAL(38, 2),
    window_start TIMESTAMP(3),
    window_end TIMESTAMP(3),
    PRIMARY KEY (customer_id, window_start) NOT ENFORCED
);


-- ############## 2. Define and Execute Streaming Aggregation Logic ##############
-- This is the core transformation logic that should be submitted as a Flink job.
-- It performs a streaming join, aggregates results over a 10-minute window,
-- and inserts them into the DWD table.
INSERT INTO dwd.customer_order_aggregation
SELECT
    -- Grouping keys
    c.customer_id,
    c.customer_name,
    c.region,
    -- Aggregation
    SUM(o.amount) AS total_amount,
    -- Window time boundaries
    TUMBLE_START(o.order_date, INTERVAL '10' MINUTE) AS window_start,
    TUMBLE_END(o.order_date, INTERVAL '10' MINUTE) AS window_end
FROM
    -- The temporal join now works because the watermark is defined on 'ods_orders'.
    ods.ods_orders AS o
JOIN
    ods.ods_customers FOR SYSTEM_TIME AS OF o.order_date AS c
    ON o.customer_id = c.customer_id
GROUP BY
    c.customer_id,
    c.customer_name,
    c.region,
    -- Group by the 10-minute tumbling window on the order_date.
    TUMBLE(o.order_date, INTERVAL '10' MINUTE);
