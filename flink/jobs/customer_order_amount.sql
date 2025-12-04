SET 'execution.runtime-mode' = 'streaming';

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

-- Create a new table to store the aggregated results
CREATE TABLE IF NOT EXISTS customer_order_summary (
    customer_id INT,
    total_amount DECIMAL(10, 2),
    PRIMARY KEY (customer_id) NOT ENFORCED
) WITH (
    'connector' = 'paimon',
    'changelog-producer' = 'input',
    'file.format' = 'parquet'
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
