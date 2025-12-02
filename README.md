# docker compose 项目框架

一个包含 FastAPI 应用、PostgreSQL 和 Redis 的基础 docker-compose 模板，适合作为新项目的起点。

## 目录结构
- `docker-compose.yml`：服务编排
- `app/`：应用源代码与镜像构建文件
  - `Dockerfile`
  - `requirements.txt`
  - `main.py`
- `mssql/`：SQL Server 自定义镜像（含 ODS 初始化脚本）
- `.env.example`：数据库默认环境变量示例

## 快速开始
```bash
cp .env.example .env          # 如需修改数据库账号密码可编辑 .env
docker compose up -d --build  # 首次启动时构建镜像
```

启动完成后：
- API: http://localhost:8000/
- 健康检查: http://localhost:8000/health
- PostgreSQL: localhost:5432（默认 demo/demo）
- SQL Server: localhost:1433（SA 密码见 `.env`，默认 `YourStrong!Passw0rd`）
- MinIO: S3 API http://localhost:9000，控制台 http://localhost:9001（默认账号 `MINIO_ROOT_USER`/`MINIO_ROOT_PASSWORD`）
- SeaTunnel: 容器内运行，挂载配置 `seatunnel/config`

## 常用操作
- 启动全部：`docker compose up -d --build`
- 启动单个组件：
  - API：`docker compose up -d api`
  - PostgreSQL：`docker compose up -d db`
  - SQL Server：`docker compose up -d mssql`
  - MinIO：`docker compose up -d minio`
  - SeaTunnel：`docker compose up -d seatunnel`
- 停止单个组件：`docker compose stop api`（或 `db` / `mssql` / `minio` / `seatunnel`）
- 停止并清理：`docker compose down -v`
- 查看日志：`docker compose logs -f api`（或 `db` / `mssql` / `minio` / `seatunnel`）
- 进入容器：
  - API：`docker compose exec api /bin/bash`
  - PostgreSQL：`docker compose exec db psql -U $POSTGRES_USER -d $POSTGRES_DB`
  - SQL Server：`docker compose exec mssql sqlcmd -S localhost -U SA -P $MSSQL_SA_PASSWORD -C`
  - MinIO：`docker compose exec minio /bin/sh`
  - SeaTunnel：`docker compose exec seatunnel /bin/bash`

## SQL Server ODS 说明
- `mssql/ods_seed.sql` 会在容器启动时创建 `ods` 数据库并写入演示表：`ods_customers` 与 `ods_orders`（含外键，可 join），作为后续 ETL 的 ODS 数据源，并为两张表开启 CDC（Change Data Capture）。
- 如需调整种子数据或表结构，可修改 `mssql/ods_seed.sql` 并重建镜像：`docker compose build mssql && docker compose up -d`.

### 连续写入配置（实时模拟 ODS 数据）
- 默认开启连续写入 `ods_orders`，可通过 `.env` 调参：
  - `ODS_WRITE_ENABLED`：是否开启连续写入（默认 `true`）
  - `ODS_WRITE_INTERVAL_SECONDS`：写入间隔秒数（默认 `2`）
  - `ODS_WRITE_BATCH_SIZE`：每次写入的行数（默认 `1`）
  - `ODS_WRITE_MAX_ROWS`：最多写入多少行后停止（默认 `0` 表示不限制）
- 写入脚本位于 `mssql/ods_writer.sh`，由 `entrypoint.sh` 启动；如需更改逻辑可修改脚本后重建镜像。

### 连接示例
- API：`http://localhost:8000/`
- PostgreSQL：`psql postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@localhost:5432/$POSTGRES_DB`
- SQL Server（容器内）：`docker compose exec mssql sqlcmd -S localhost -U SA -P $MSSQL_SA_PASSWORD -C`
- SQL Server（本机客户端）：服务器 `localhost`, 端口 `1433`, 用户 `SA`, 密码取自 `.env`。
- MinIO S3：`http://localhost:9000`，访问密钥/密钥取 `.env` 中 `MINIO_ROOT_USER`/`MINIO_ROOT_PASSWORD`
- MinIO 控制台：浏览器打开 `http://localhost:9001`
- SeaTunnel：容器内执行任务，例如 `docker compose exec seatunnel ./bin/seatunnel.sh --config /opt/config/user_config/seatunnel.conf -m local`

## SeaTunnel 说明
- 镜像使用 `apache/seatunnel:2.3.12`，已挂载本地配置目录 `seatunnel/config` 和日志目录 `seatunnel/logs`。
- 默认命令 `sleep infinity`，保持容器存活；运行任务请使用：  
  `docker compose exec seatunnel ./bin/seatunnel.sh --config /opt/config/user_config/seatunnel.conf -m local`
- 示例配置：
  - `seatunnel/config/seatunnel.conf`：FakeSource -> Console。
  - `seatunnel/config/sqlserver_to_paimon.conf`：SQL Server CDC 多表（`ods_customers`、`ods_orders`）写入 MinIO 上的 Paimon，按 SeaTunnel 2.3.12 多表示例配置。
    - 依赖环境变量：`MSSQL_SA_PASSWORD`、`MINIO_ROOT_USER`、`MINIO_ROOT_PASSWORD`、`PAIMON_BUCKET`（默认 `paimon-warehouse`）。
    - 运行示例：`docker compose exec seatunnel ./bin/seatunnel.sh --config /opt/config/user_config/sqlserver_to_paimon.conf -m local`
    - 请先在 MinIO 创建桶 `${PAIMON_BUCKET}`（默认 `paimon-warehouse`），例如：
      - `docker compose exec minio mc alias set local http://localhost:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD`
      - `docker compose exec minio mc mb local/$PAIMON_BUCKET`
- 插件：SQLServer CDC -> Paimon 需要安装连接器（2.3.12 对应版本）。首次使用前在 seatunnel 容器内执行：
  - `docker compose exec seatunnel /bin/sh /opt/seatunnel/install-plugins.sh`
  - 如需手动命令：`docker compose exec seatunnel ./bin/install-plugin.sh --plugins seatunnel-connector-v2-sqlserver-cdc,seatunnel-connector-v2-paimon`

## 扩展思路
- 在 `app/main.py` 中添加业务路由；按需调整依赖
- 修改 `docker-compose.yml` 添加新的服务（如队列、前端、任务调度等）
- 使用 `.env` 覆盖默认变量并在 CI/CD 中引用
