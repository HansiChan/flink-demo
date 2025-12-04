#!/bin/sh
set -e

# Submit PyFlink job with explicit python executable
/opt/flink/bin/flink run \
  -py /opt/flink/usrtmp/jobs/ods_user_total_spend.py \
  -pyexec /opt/venv/bin/python3 \
  -d
