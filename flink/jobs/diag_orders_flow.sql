SET 'execution.runtime-mode' = 'streaming';
SET 'table.exec.sink.upsert-materialize' = 'NONE';
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

DROP TABLE IF EXISTS orders_test_sink;

-- Create a simple sink table to test data flow
CREATE TABLE IF NOT EXISTS orders_test_sink (
    order_id INT,
    customer_id INT,
    order_date TIMESTAMP(3),
    amount DECIMAL(10, 2),
    PRIMARY KEY (order_id) NOT ENFORCED
);

-- Directly insert data from the orders table
INSERT INTO orders_test_sink
SELECT
    order_id,
    customer_id,
    order_date,
    amount
FROM
    ods.ods_orders;
