#!/usr/bin/env bash
set -euo pipefail

if [ -z "$MSSQL_SA_PASSWORD" ]; then
  echo "MSSQL_SA_PASSWORD must be set"
  exit 1
fi

SQLCMD_BIN=${SQLCMD_BIN:-sqlcmd}

/opt/mssql/bin/sqlservr &
sqlservr_pid=$!

# Wait for SQL Server to accept connections
for i in {1..30}; do
  $SQLCMD_BIN -S localhost -U SA -P "$MSSQL_SA_PASSWORD" -Q "SELECT 1" >/dev/null 2>&1 && break
  echo "Waiting for SQL Server to start... ($i/30)"
  sleep 2
done

# Seed ODS data
$SQLCMD_BIN -S localhost -U SA -P "$MSSQL_SA_PASSWORD" -d master -i /docker-entrypoint-initdb.d/ods_seed.sql

# Optional continuous writer for ODS orders
ODS_WRITE_ENABLED=${ODS_WRITE_ENABLED:-true}
ODS_WRITE_INTERVAL_SECONDS=${ODS_WRITE_INTERVAL_SECONDS:-2}
ODS_WRITE_BATCH_SIZE=${ODS_WRITE_BATCH_SIZE:-1}
ODS_WRITE_MAX_ROWS=${ODS_WRITE_MAX_ROWS:-0} # 0 means unlimited

if [[ "$ODS_WRITE_ENABLED" == "true" && "$ODS_WRITE_INTERVAL_SECONDS" -gt 0 ]]; then
  echo "Starting ODS writer: interval=${ODS_WRITE_INTERVAL_SECONDS}s batch=${ODS_WRITE_BATCH_SIZE} max_rows=${ODS_WRITE_MAX_ROWS}"
  /usr/local/bin/ods_writer.sh \
    "$MSSQL_SA_PASSWORD" \
    "$ODS_WRITE_INTERVAL_SECONDS" \
    "$ODS_WRITE_BATCH_SIZE" \
    "$ODS_WRITE_MAX_ROWS" &
fi

wait $sqlservr_pid
