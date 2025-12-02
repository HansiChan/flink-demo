#!/usr/bin/env sh
set -e

# Install required connectors for SQLServer CDC -> Paimon on MinIO
cd /opt/seatunnel
./bin/install-plugin.sh --plugins seatunnel-connector-v2-sqlserver-cdc,seatunnel-connector-v2-paimon
