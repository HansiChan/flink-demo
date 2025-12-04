#!/bin/sh
set -e

# 启动 StarRocks all-in-one 容器
cd "$(dirname "$0")/.." || exit 1

docker compose up -d starrocks
