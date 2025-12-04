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

-- Drop the table if it exists to ensure schema is updated
DROP TABLE IF EXISTS customer_total_orders;

-- Create a table to store the aggregated customer order amounts
CREATE TABLE IF NOT EXISTS customer_total_orders (
    customer_id INT,
    customer_name STRING,
    total_amount DECIMAL(10, 2),
    PRIMARY KEY (customer_id) NOT ENFORCED
);

-- Insert the aggregated customer order amounts into the new table
INSERT INTO customer_total_orders
SELECT
    c.customer_id,
    c.customer_name,
    SUM(o.amount) AS total_amount
FROM
    ods.ods_customers AS c
JOIN
    ods.ods_orders AS o ON c.customer_id = o.customer_id
GROUP BY
    c.customer_id, c.customer_name;
