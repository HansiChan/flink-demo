SET 'execution.runtime-mode' = 'streaming';
SET 'table.dynamic-table-options.enabled' = 'true';

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

ALTER TABLE ods_orders SET ('scan.mode' = 'latest-full');
ALTER TABLE ods_customers SET ('scan.mode' = 'latest-full');

-- Create a new table to store the aggregated results
CREATE TABLE IF NOT EXISTS customer_order_summary (
    customer_id INT,
    total_amount DECIMAL(10, 2),
    PRIMARY KEY (customer_id) NOT ENFORCED
) WITH (
    'connector' = 'paimon',
    'changelog-producer' = 'input',
    'file.format' = 'parquet',
    'write-only' = 'false',
    'table.exec.sink.upsert-materialize' = 'true'
);

-- a sql that calculate total order amount for each customer
INSERT INTO customer_order_summary
SELECT
    c.customer_id,
    SUM(o.amount) AS total_amount
FROM
    ods_customers c
JOIN
    ods_orders o ON c.customer_id = o.customer_id
GROUP BY
    c.customer_id;
