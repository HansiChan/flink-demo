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

select * from paimon_catalog_fs.ods.ods_orders where order_id=2;
select count(*) from paimon_catalog_fs.ods.ods_orders;

create database demo_db;
use demo_db;

