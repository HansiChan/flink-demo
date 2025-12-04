CREATE CATALOG paimon WITH (
    'type' = 'paimon',
    'warehouse' = 's3://demo/ods',
    's3.access-key' = 'minioadmin',
    's3.secret-key' = 'minioadmin',
    's3.endpoint' = 'http://minio:9000',
    's3.path.style.access' = 'true'
);

USE CATALOG paimon;

-- Create a view of the ods_orders table
CREATE TEMPORARY VIEW ods_orders_view AS
SELECT
    *
FROM
    ods_orders;

-- Create a view of the ods_customers table
CREATE TEMPORARY VIEW ods_customers_view AS
SELECT
    *
FROM
    ods_customers;

-- Create a new table to store the aggregated results
CREATE TABLE IF NOT EXISTS customer_order_summary (
    customer_id INT,
    total_order_amount DECIMAL(10, 2),
    PRIMARY KEY (customer_id) NOT ENFORCED
) WITH (
    'connector' = 'paimon',
    'changelog-producer' = 'full-compaction',
    'file.format' = 'parquet'
);

-- a sql that calculate total order amount for each customer
INSERT INTO customer_order_summary
SELECT
    c.customer_id,
    SUM(o.order_amount) AS total_order_amount
FROM
    ods_customers_view c
JOIN
    ods_orders_view o ON c.customer_id = o.customer_id
GROUP BY
    c.customer_id;
