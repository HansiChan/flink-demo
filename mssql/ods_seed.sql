-- Create ODS database and seed sample data for ETL
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'ods')
BEGIN
    CREATE DATABASE ods;
END;
GO

USE ods;
GO

-- Disable CDC on existing tables before drop (otherwise DROP TABLE will fail)
IF OBJECT_ID('ods_orders') IS NOT NULL AND EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID('ods_orders') AND is_tracked_by_cdc = 1)
BEGIN
    EXEC sys.sp_cdc_disable_table @source_schema = N'dbo', @source_name = N'ods_orders', @capture_instance = N'dbo_ods_orders';
END;

IF OBJECT_ID('ods_customers') IS NOT NULL AND EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID('ods_customers') AND is_tracked_by_cdc = 1)
BEGIN
    EXEC sys.sp_cdc_disable_table @source_schema = N'dbo', @source_name = N'ods_customers', @capture_instance = N'dbo_ods_customers';
END;

IF OBJECT_ID('ods_customers') IS NOT NULL DROP TABLE ods_customers;
IF OBJECT_ID('ods_orders') IS NOT NULL DROP TABLE ods_orders;
GO

CREATE TABLE ods_customers (
    customer_id INT IDENTITY(1,1) PRIMARY KEY,
    customer_name NVARCHAR(100) NOT NULL,
    region NVARCHAR(50) NOT NULL,
    created_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE ods_orders (
    order_id INT IDENTITY(1,1) PRIMARY KEY,
    customer_id INT NOT NULL,
    order_date DATETIME2 NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    status NVARCHAR(20) NOT NULL,
    created_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES ods_customers(customer_id)
);
GO

INSERT INTO ods_customers (customer_name, region)
VALUES
    (N'Alice', N'North'),
    (N'Bob', N'South'),
    (N'Charlie', N'East'),
    (N'Diana', N'West');
GO

INSERT INTO ods_orders (customer_id, order_date, amount, status)
VALUES
    (1, DATEADD(day, -2, SYSUTCDATETIME()), 199.99, 'pending'),
    (2, DATEADD(day, -1, SYSUTCDATETIME()), 349.50, 'paid'),
    (3, SYSUTCDATETIME(), 89.00, 'failed'),
    (4, SYSUTCDATETIME(), 1200.00, 'paid'),
    (2, SYSUTCDATETIME(), 50.00, 'paid');
GO

-- Enable CDC at database level (idempotent)
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'ods' AND is_cdc_enabled = 0)
BEGIN
    EXEC sys.sp_cdc_enable_db;
END;

-- Enable CDC for both tables to support downstream ETL
IF NOT EXISTS (SELECT 1 FROM cdc.change_tables WHERE source_object_id = OBJECT_ID('dbo.ods_customers'))
BEGIN
    EXEC sys.sp_cdc_enable_table
        @source_schema = N'dbo',
        @source_name   = N'ods_customers',
        @role_name     = NULL,
        @supports_net_changes = 1;
END;

IF NOT EXISTS (SELECT 1 FROM cdc.change_tables WHERE source_object_id = OBJECT_ID('dbo.ods_orders'))
BEGIN
    EXEC sys.sp_cdc_enable_table
        @source_schema = N'dbo',
        @source_name   = N'ods_orders',
        @role_name     = NULL,
        @supports_net_changes = 1;
END;
GO
