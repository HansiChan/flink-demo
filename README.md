# Flink Demo

A Docker Compose-based environment for data synchronization/CDC experiments, including SQL Server, MinIO, SeaTunnel cluster, Flink, and StarRocks.

## Directory Structure

```
.
├── docker-compose.yml      # Service orchestration
├── mssql/                  # SQL Server image (with ODS init scripts)
│   ├── Dockerfile
│   ├── entrypoint.sh
│   ├── ods_seed.sql        # Seed data
│   └── ods_writer.sh       # Continuous write script
├── flink/                  # Flink related
│   ├── flink-plugins/      # Flink plugins (e.g., Paimon connector)
│   ├── jobs/               # SQL job scripts
│   └── script/             # Helper scripts
├── seatunnel/              # SeaTunnel related
│   ├── config/             # Job configurations
│   ├── lib/                # Additional dependencies
│   └── script/             # Helper scripts
├── starrocks/              # StarRocks related
│   └── sql/                # SQL scripts
└── .env.example            # Environment variables example
```

## Components Overview

| Component | Description | Access |
|-----------|-------------|--------|
| **SQL Server** | ODS data source with `ods_customers` and `ods_orders` tables | `localhost:1433` |
| **MinIO** | S3-compatible object storage for Paimon warehouse | API: `localhost:9000`, Console: `localhost:9001` |
| **SeaTunnel** | Data integration platform (1 Master + 2 Workers) | REST: `localhost:5801` |
| **Flink** | Stream processing framework (JobManager + TaskManager) | UI: `localhost:8081` |
| **StarRocks** | Distributed SQL analytics database | HTTP: `8030`, MySQL: `9030` |

## Quick Start

```bash
cp .env.example .env          # Modify environment variables as needed
docker-compose up -d --build  # Build images on first launch
```

## Common Commands

```bash
# Start/Stop
docker-compose up -d --build                      # Start all services
docker-compose up -d mssql minio                  # Start specific services
docker-compose up -d master worker1 worker2       # Start SeaTunnel cluster
docker-compose up -d jobmanager taskmanager       # Start Flink cluster
docker-compose stop                               # Stop all services
docker-compose down -v                            # Stop and remove volumes

# Logs
docker-compose logs -f mssql                      # View service logs

# Shell access
docker-compose exec mssql sqlcmd -S localhost -U SA -P $MSSQL_SA_PASSWORD -C
docker-compose exec jobmanager /bin/bash
docker-compose exec starrocks /bin/bash
```

## SQL Server (ODS Data Source)

On startup, `mssql/ods_seed.sql` creates the `ods` database and initializes `ods_customers` and `ods_orders` tables with CDC enabled.

**Continuous Write Configuration** (simulates real-time data, configured via `.env`):

| Variable | Description | Default |
|----------|-------------|---------|
| `ODS_WRITE_ENABLED` | Enable continuous writing | `true` |
| `ODS_WRITE_INTERVAL_SECONDS` | Write interval (seconds) | `2` |
| `ODS_WRITE_BATCH_SIZE` | Rows per batch | `1` |

## SeaTunnel

Image: `apache/seatunnel`, config directory mounted to `seatunnel/config`.

Example job `seatunnel/config/sqlserver_to_paimon.conf` demonstrates reading CDC data from SQL Server and writing to Paimon.

```bash
# Run example (create paimon-warehouse bucket in MinIO first)
sh seatunnel/script/start_task.sh
```

## Flink

Image: `flink:1.20.2-scala_2.12-java11`

- Job scripts: `flink/jobs/` → mounted to `/opt/flink/usrjob`
- Plugin JARs: `flink/flink-plugins/` → mounted to `/opt/flink/lib/userlib`

```bash
# Submit SQL job
docker-compose exec jobmanager ./bin/sql-client.sh -f /opt/flink/usrjob/<your_job>.sql

# Cancel job: via UI (localhost:8081) or CLI
docker-compose exec jobmanager ./bin/flink list
docker-compose exec jobmanager ./bin/flink cancel <jobId>
```

## StarRocks

Image: `starrocks/allin1-ubuntu`

```bash
# Connect to StarRocks
mysql -h 127.0.0.1 -P 9030 -u root
```

## Extension Ideas

- Add business services or frontend applications
- Integrate message queues (Kafka, etc.)
- Use `.env` with CI/CD pipelines for environment management