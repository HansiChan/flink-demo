#!/bin/sh
set -e

# 停止 StarRocks all-in-one 容器
cd "$(dirname "$0")/.." || exit 1

docker compose stop starrocks
