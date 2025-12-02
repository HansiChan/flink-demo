-- Create ODS database and seed sample data for ETL
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'ods')
BEGIN
    CREATE DATABASE ods;
END;
GO

USE ods;
GO

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
