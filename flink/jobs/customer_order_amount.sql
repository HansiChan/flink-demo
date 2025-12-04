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
