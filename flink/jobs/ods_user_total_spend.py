"""
PyFlink streaming job:
- Source: Paimon table ods.ods_orders (streaming read)
- Sink:   Paimon table ods.user_total_spend (PK: customer_id) with running total + latest order time
Requires jars in Flink lib:
  - paimon-flink-1.18-<version>.jar
  - flink-s3-fs-presto-1.18.0.jar (or hadoop) for MinIO/S3 access
"""

from pyflink.table import EnvironmentSettings, TableEnvironment


def main() -> None:
    settings = EnvironmentSettings.in_streaming_mode()
    t_env = TableEnvironment.create(settings)

    # Basic streaming settings
    conf = t_env.get_config().get_configuration()
    conf.set_string("pipeline.name", "ods_user_total_spend")
    conf.set_string("execution.checkpointing.interval", "10 s")

    # Register Paimon catalog on MinIO
    t_env.execute_sql(
        """
        CREATE CATALOG paimon_catalog WITH (
            'type' = 'paimon',
            'warehouse' = 's3a://demo/',
            'fs.s3a.access.key' = 'minioadmin',
            'fs.s3a.secret.key' = 'minioadmin',
            'fs.s3a.endpoint' = 'http://minio:9000',
            'fs.s3a.path.style.access' = 'true'
        )
        """
    )
    t_env.execute_sql("USE CATALOG paimon_catalog")
    t_env.execute_sql("CREATE DATABASE IF NOT EXISTS ods")

    # Source table (already written by SeaTunnel). Schema must match Paimon table definition.
    t_env.execute_sql(
        """
        CREATE TABLE IF NOT EXISTS ods.ods_orders (
            order_id INT,
            customer_id INT,
            order_date TIMESTAMP(6),
            amount DECIMAL(10, 2),
            status STRING,
            created_at TIMESTAMP(6),
            PRIMARY KEY (order_id) NOT ENFORCED
        ) WITH (
            'changelog-producer' = 'full-compaction'
        )
        """
    )

    # Sink table for running total per user
    t_env.execute_sql(
        """
        CREATE TABLE IF NOT EXISTS ods.user_total_spend (
            customer_id INT,
            total_amount DECIMAL(18, 2),
            last_order_time TIMESTAMP(6),
            PRIMARY KEY (customer_id) NOT ENFORCED
        ) WITH (
            'changelog-producer' = 'lookup'
        )
        """
    )

    # Continuous aggregation
    t_env.execute_sql(
        """
        INSERT INTO ods.user_total_spend
        SELECT
            customer_id,
            SUM(amount) AS total_amount,
            MAX(order_date) AS last_order_time
        FROM ods.ods_orders
        GROUP BY customer_id
        """
    )


if __name__ == "__main__":
    main()
