#!/usr/bin/env bash
set -euo pipefail

SA_PASSWORD=$1
INTERVAL_SECONDS=$2
BATCH_SIZE=$3
MAX_ROWS=$4
SQLCMD_BIN=${SQLCMD_BIN:-sqlcmd}
SQLCMD_OPTS=${SQLCMD_OPTS:-"-C"}

insert_batch() {
  local inserts=$1
  $SQLCMD_BIN -S localhost -U SA -P "$SA_PASSWORD" $SQLCMD_OPTS -d ods -b -Q "
    SET NOCOUNT ON;
    DECLARE @i INT = 0;
    WHILE @i < $inserts
    BEGIN
      INSERT INTO ods_orders (customer_id, order_date, amount, status)
      SELECT TOP 1
        customer_id,
        DATEADD(second, -ABS(CHECKSUM(NEWID())) % 600, SYSUTCDATETIME()),
        CAST((ABS(CHECKSUM(NEWID())) % 100000) / 100.0 AS DECIMAL(10,2)),
        CASE ABS(CHECKSUM(NEWID())) % 3 WHEN 0 THEN 'pending' WHEN 1 THEN 'paid' ELSE 'failed' END
      FROM ods_customers
      ORDER BY NEWID();
      SET @i = @i + 1;
    END;
  "
}

while true; do
  current=$($SQLCMD_BIN -S localhost -U SA -P "$SA_PASSWORD" $SQLCMD_OPTS -d ods -h -1 -Q "SET NOCOUNT ON; SELECT COUNT(*) FROM ods_orders;" | tr -d '\r')
  current=${current:-0}

  if [[ "$MAX_ROWS" -gt 0 && "$current" -ge "$MAX_ROWS" ]]; then
    echo "ODS writer reached max rows ($MAX_ROWS), exiting."
    break
  fi

  batch=$BATCH_SIZE
  if [[ "$MAX_ROWS" -gt 0 ]]; then
    remaining=$((MAX_ROWS - current))
    if [[ $remaining -lt $batch ]]; then
      batch=$remaining
    fi
  fi

  insert_batch "$batch"
  sleep "$INTERVAL_SECONDS"
done
