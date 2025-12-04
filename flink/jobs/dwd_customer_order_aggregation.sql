-- Flink SQL Job: dwd_customer_order_aggregation
-- Description: Aggregates customer orders from ODS to DWD layer.
--
-- =================================== IMPORTANT =====================================
-- This script now uses a TEMPORARY TABLE ('watermarked_orders') to define the
-- watermark for the orders stream directly. This bypasses issues with metadata
-- not persisting in the Paimon catalog via ALTER TABLE.
--
-- You can run this entire script directly in the Flink SQL Client or via 'flink run'.
-- ===================================================================================

-- ############## 1. Catalog and DWD Table Setup ##############
CREATE CATALOG paimon WITH (
    'type' = 'paimon',
    'warehouse' = 's3a://demo/',
    's3.endpoint' = 'http://minio:9000',
    's3.access-key' = 'minioadmin',
    's3.secret-key' = 'minioadmin',
    's3.path.style.access' = 'true'
);

USE CATALOG paimon;

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


-- ############## 2. Define a Watermarked Source Table (WORKAROUND) ##############
-- Create a TEMPORARY table that points to the physical Paimon 'ods_orders' table
-- but explicitly defines the watermark for Flink's stream planner.
CREATE TEMPORARY TABLE watermarked_orders (
    order_id INT,
    customer_id INT,
    -- The type must match the underlying Paimon table (TIMESTAMP(7) as seen in DESCRIBE)
    order_date TIMESTAMP(7),
    amount DECIMAL(10, 2),
    status STRING,
    created_at TIMESTAMP(7),
    -- This WATERMARK definition is the key to fixing the temporal join error.
    WATERMARK FOR order_date AS order_date - INTERVAL '1' SECOND
) WITH (
    'connector' = 'paimon',
    -- Provide the full physical path to the Paimon table in S3.
    -- Paimon creates database folders with a '.db' suffix.
    'path' = 's3://demo/',
    -- Must include S3 settings again as this is a separate table definition.
    's3.endpoint' = 'http://minio:9000',
    's3.access-key' = 'minioadmin',
    's3.secret-key' = 'minioadmin',
    's3.path.style.access' = 'true'
);


-- ############## 3. Define and Execute Streaming Aggregation Logic ##############
-- The query is the same as before, but it reads from our new temporary table.
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
    -- Use the new 'watermarked_orders' temporary table as the left side of the join.
    watermarked_orders AS o
JOIN
    -- The customers table can still be read directly from the catalog.
    ods.ods_customers FOR SYSTEM_TIME AS OF o.order_date AS c
    ON o.customer_id = c.customer_id
GROUP BY
    c.customer_id,
    c.customer_name,
    c.region,
    -- Group by the 10-minute tumbling window on the order_date.
    TUMBLE(o.order_date, INTERVAL '10' MINUTE);
