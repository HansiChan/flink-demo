# Docker Compose Project Framework

A docker-compose template that includes SQL Server, MinIO, a SeaTunnel cluster (1 Master + 2 Workers), and Flink. It is suitable as a starting point for data synchronization/CDC experiences.

## Directory Structure
- `docker-compose.yml`: Service orchestration
- `mssql/`: Custom SQL Server image (including ODS initialization script)
- `flink/`: Flink-related files
  - `flink-plugins/`: For Flink plugins like Paimon connector.
  - `jobs/`: SQL job scripts.
- `seatunnel/`: SeaTunnel configuration and scripts.
- `.env.example`: Example for default database environment variables.

## Project Components Overview

| Component     | Description                                                                     | Access Point(s)                                                        |
|---------------|---------------------------------------------------------------------------------|------------------------------------------------------------------------|
| **SQL Server**| MSSQL database for ODS data, seeded with `ods_customers` and `ods_orders`.    | `localhost:1433` (SA user, password from `.env`)                       |
| **MinIO**     | S3-compatible object storage, used for Paimon warehouse.                       | S3 API: `http://localhost:9000`, Console: `http://localhost:9001`      |
| **SeaTunnel** | Data integration platform for ETL/ELT tasks (1 Master + 2 Workers).           | Master REST: `5801`, User configs: `seatunnel/config`                  |
| **Flink**     | Stream processing framework (JobManager + TaskManager) for SQL jobs.          | JobManager UI: `http://localhost:8081`                                 |
| **StarRocks** | Distributed SQL Data Warehouse for high-performance analytics.                 | FE HTTP: `8030`, BE HTTP: `8040`, FE MySQL: `9030` (service `starrocks`)|



## Quick Start
```bash
cp .env.example .env          # Edit .env if you need to change database credentials
docker-compose up -d --build  # Build images on first launch
```

After startup, refer to the "Project Components Overview" table for access points and details of each service.

## Common Operations
- **Start all services**: `docker-compose up -d --build`
- **Start a single component**:
  - SQL Server: `docker-compose up -d mssql`
  - MinIO: `docker-compose up -d minio`
  - SeaTunnel Cluster: `docker-compose up -d master worker1 worker2`
  - Flink Cluster: `docker-compose up -d jobmanager taskmanager`
  - StarRocks: `docker-compose up -d starrocks`
- **Stop a single component**: `docker-compose stop mssql` (or `minio`, `seatunnel`, etc.)
- **Stop and clean up**: `docker-compose down -v`
- **View logs**: `docker-compose logs -f mssql` (or `minio`, `jobmanager`, etc.)
- **Execute a command in a container**:
  - SQL Server: `docker-compose exec mssql sqlcmd -S localhost -U SA -P $MSSQL_SA_PASSWORD -C`
  - MinIO: `docker-compose exec minio /bin/sh`
  - SeaTunnel Master: `docker-compose exec seatunnel /bin/bash`
  - Flink JobManager: `docker-compose exec jobmanager /bin/bash`
  - StarRocks: `docker-compose exec starrocks /bin/bash`

## SQL Server ODS Notes
- The `mssql/ods_seed.sql` script creates the `ods` database and seeds it with demo tables (`ods_customers` and `ods_orders` with a foreign key relationship) when the container starts. These tables serve as the ODS data source for subsequent ETL processes. CDC (Change Data Capture) is enabled for both tables.
- To modify the seed data or table structure, edit `mssql/ods_seed.sql` and rebuild the image: `docker-compose build mssql && docker-compose up -d mssql`.

### Continuous Data Writing (Simulating Real-time ODS Data)
- By default, a process continuously writes to the `ods_orders` table. You can configure this via `.env`:
  - `ODS_WRITE_ENABLED`: Enables or disables continuous writing (default: `true`).
  - `ODS_WRITE_INTERVAL_SECONDS`: Interval between writes in seconds (default: `2`).
  - `ODS_WRITE_BATCH_SIZE`: Number of rows to write in each batch (default: `1`).
- The writer script is `mssql/ods_writer.sh`, started by `entrypoint.sh`. Modify the script and rebuild the image to change the logic.

## SeaTunnel Notes
- The image uses `apache/seatunnel:2.3.12`. The local configuration directory `seatunnel/config` is mounted into the container.
- An example job `seatunnel/config/sqlserver_to_paimon.conf` demonstrates reading CDC data from two SQL Server tables (`ods_customers`, `ods_orders`) and writing to a Paimon table on MinIO.
  - To run the example: `sh seatunnel/script/start_task.sh`
  - **Prerequisite**: Create the Paimon bucket in MinIO first (default: `paimon-warehouse`).

## Flink (SQL Example)
- The Flink cluster uses the official `flink:1.20.1` image.
- The local `flink/jobs` directory is mounted to `/opt/flink/usrlib` in the container.
- Plugin JARs (e.g., for Paimon, S3) are placed in `flink/flink-plugins/` and mounted to `/opt/flink/plugins` in the container.
- Example job: `flink/jobs/customer_order_amount.sql` (real-time aggregation of `ods_orders` and `ods_customers`, writing to a Paimon table).

### Starting and Stopping the Flink Cluster
- **Start the cluster**:
  ```bash
  docker-compose up -d jobmanager taskmanager
  ```
- **Stop the cluster**:
  ```bash
  docker-compose stop jobmanager taskmanager
  ```

### Submitting a Flink SQL Streaming Job
- Before running, ensure that the required plugin JARs (e.g., `paimon-flink-*.jar`) compatible with Flink 1.20.1 are in the `flink/flink-plugins` directory.
- **Submit the job**:
  ```bash
  docker-compose exec jobmanager ./bin/sql-client.sh -f /opt/flink/usrjob/customer_order_amount.sql
  ```
- You can stop the job via the Flink UI (`http://localhost:8081`) or by using the command line (`./bin/flink list` followed by `./bin/flink cancel <jobId>`).

## Further Extension Ideas
- Add business logic to an application service.
- Add new services (e.g., message queues, front-end applications, task schedulers) to `docker-compose.yml`.
- Use `.env` to override default variables and reference them in a CI/CD pipeline.