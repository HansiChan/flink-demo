SET 'execution.runtime-mode' = 'streaming';
SET 'table.dynamic-table-options.enabled' = 'true';
SET 'table.exec.sink.upsert-materialize' = 'NONE';

CREATE CATALOG paimon WITH (
    'type' = 'paimon',
    'warehouse' = 's3://demo/',
    's3.access-key' = 'minioadmin',
    's3.secret-key' = 'minioadmin',
    's3.endpoint' = 'http://minio:9000',
    's3.path.style.access' = 'true'
);

USE CATALOG paimon;

USE ods;

-- Drop the table if it exists to ensure schema is updated
DROP TABLE IF EXISTS daily_customer_summary;

-- Create a partitioned table to store the daily aggregated customer order amounts
CREATE TABLE IF NOT EXISTS daily_customer_summary (
    customer_id INT,
    customer_name STRING,
    total_amount DECIMAL(10, 2),
    dt DATE,  -- Partition key
    PRIMARY KEY (dt, customer_id) NOT ENFORCED
) PARTITIONED BY (dt);

-- Insert the aggregated daily customer order amounts into the new partitioned table
INSERT INTO daily_customer_summary
SELECT
    c.customer_id,
    c.customer_name,
    SUM(o.amount) AS total_amount,
    CAST(o.order_date AS DATE) AS dt
FROM
    ods.ods_customers AS c
JOIN
    ods.ods_orders AS o ON c.customer_id = o.customer_id
GROUP BY
    CAST(o.order_date AS DATE),
    c.customer_id,
    c.customer_name;