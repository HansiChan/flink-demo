-- Flink SQL Job: dwd_customer_order_aggregation
-- Description: This job aggregates customer orders every 10 minutes from the ODS layer
-- and writes the results to a DWD layer Paimon table.

-- ############## 1. Catalog and Environment Setup ##############
-- Create a Paimon catalog to connect to the data lakehouse on MinIO.
-- The warehouse path 's3a://warehouse/' assumes you store Paimon data in a bucket named 'warehouse'.
-- Please ensure the Flink cluster has the correct S3 filesystem jars (flink-s3-fs-hadoop) available.
CREATE CATALOG paimon WITH (
    'type' = 'paimon',
    'warehouse' = 's3a://warehouse/',
    's3.endpoint' = 'http://minio:9000',
    's3.access-key' = 'minioadmin',
    's3.secret-key' = 'minioadmin',
    's3.path.style.access' = 'true'
);

-- Switch to the Paimon catalog for the current session.
USE CATALOG paimon;

-- Create the database for the DWD (Data Warehouse Detail) layer if it doesn't exist.
CREATE DATABASE IF NOT EXISTS dwd;


-- ############## 2. Define Target Table (Sink) ##############
-- Create the aggregation target table in the DWD layer.
-- This table will store the total order amount for each customer within a 10-minute window.
-- It includes customer details for easier downstream analysis.
-- The primary key ensures that updates for the same customer and window are handled correctly (upsert).
CREATE TABLE IF NOT EXISTS dwd.customer_order_aggregation (
    customer_id BIGINT,
    customer_name STRING,
    region STRING,
    total_amount DECIMAL(38, 2),
    window_start TIMESTAMP(3),
    window_end TIMESTAMP(3),
    PRIMARY KEY (customer_id, window_start) NOT ENFORCED
);


-- ############## 3. Define and Execute Streaming Aggregation Logic ##############
-- This is the core transformation logic.
-- It performs a streaming join between orders and customers, aggregates the results
-- using a 10-minute tumbling window, and inserts them into the DWD table.
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
    -- Use 'FOR SYSTEM_TIME AS OF' for temporal join to handle changing customer data.
    -- The watermark on 'ods_orders' drives the time progress.
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

