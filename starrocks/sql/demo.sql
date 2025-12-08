CREATE EXTERNAL CATALOG paimon_catalog_fs
PROPERTIES
(
    "type" = "paimon",
    "paimon.catalog.type" = "filesystem",
    "paimon.catalog.warehouse" = "s3://demo/",
    "aws.s3.enable_ssl" = "true",
    "aws.s3.enable_path_style_access" = "true",
    "aws.s3.endpoint" = "http://minio:9000/",
    "aws.s3.access_key" = "minioadmin",
    "aws.s3.secret_key" = "minioadmin"
);
set catalog paimon_catalog_fs;
show databases;
use ods;
show tables;

select * from paimon_catalog_fs.ods.ods_orders where order_id=1;
select count(*) from paimon_catalog_fs.ods.ods_orders;

select * from paimon_catalog_fs.dwd.dwd_customer_order_hourly_metrics;
select count(*) from paimon_catalog_fs.dwd.dwd_customer_order_hourly_metrics;

set catalog default_catalog;
create database demo_db;
use demo_db;

create view ods_orders_vw as 
select * from paimon_catalog_fs.ods.ods_orders;


-- dws_customer_order_daily_metrics_mv
-- This materialized view aggregates the hourly customer order metrics into daily metrics.
CREATE MATERIALIZED VIEW dws_customer_order_daily_metrics_mv
DISTRIBUTED BY HASH(customer_id)
REFRESH ASYNC EVERY(INTERVAL 1 MINUTE)
AS
SELECT
    customer_id,
    customer_name,
    region,
    date_trunc('day', window_start) as stat_date,
    SUM(order_count) as order_count,
    SUM(total_amount) as total_amount
FROM paimon_catalog_fs.dwd.dwd_customer_order_hourly_metrics
GROUP BY
    customer_id,
    customer_name,
    region,
    date_trunc('day', window_start);

select * from demo_db.dws_customer_order_daily_metrics_mv;