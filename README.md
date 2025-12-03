# docker compose 项目框架

一个包含 SQL Server、MinIO、SeaTunnel 集群（1 Master + 2 Worker）的 docker-compose 模板，适合作为数据同步/CDC 体验的起点。

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
- SQL Server: localhost:1433（SA 密码见 `.env`）
- MinIO: S3 API http://localhost:9000，控制台 http://localhost:9001（默认账号 `MINIO_ROOT_USER`/`MINIO_ROOT_PASSWORD`）
- SeaTunnel 集群：Master (REST 5801) + Worker1 + Worker2，用户配置挂载 `seatunnel/config`

## 常用操作
- 启动全部：`docker compose up -d --build`
- 启动单个组件：
  - SQL Server：`docker compose up -d mssql`
  - MinIO：`docker compose up -d minio`
  - SeaTunnel 集群：`docker compose up -d seatunnel seatunnel-worker1 seatunnel-worker2`
- 停止单个组件：`docker compose stop mssql`（或 `minio` / `seatunnel` / `seatunnel-worker1` / `seatunnel-worker2`）
- 停止并清理：`docker compose down -v`
- 查看日志：`docker compose logs -f mssql`（或 `minio` / `seatunnel` / `seatunnel-worker1` / `seatunnel-worker2`）
- 进入容器：
  - SQL Server：`docker compose exec mssql sqlcmd -S localhost -U SA -P $MSSQL_SA_PASSWORD -C`
  - MinIO：`docker compose exec minio /bin/sh`
  - SeaTunnel Master：`docker compose exec seatunnel /bin/bash`
  - SeaTunnel Worker1：`docker compose exec seatunnel-worker1 /bin/bash`
  - SeaTunnel Worker2：`docker compose exec seatunnel-worker2 /bin/bash`

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
- SQL Server（容器内）：`docker compose exec mssql sqlcmd -S localhost -U SA -P $MSSQL_SA_PASSWORD -C`
- SQL Server（本机客户端）：服务器 `localhost`, 端口 `1433`, 用户 `SA`, 密码取自 `.env`。
- MinIO S3：`http://localhost:9000`，访问密钥/密钥取 `.env` 中 `MINIO_ROOT_USER`/`MINIO_ROOT_PASSWORD`
- MinIO 控制台：浏览器打开 `http://localhost:9001`
- SeaTunnel：
  - REST（默认 5801 暴露自 Master）
  - 运行任务：`docker compose exec seatunnel ./bin/seatunnel.sh --config /opt/seatunnel/config/user_config/sqlserver_to_paimon.conf -m cluster`

## SeaTunnel 说明
- 镜像使用 `apache/seatunnel:2.3.12`，已挂载本地配置目录 `seatunnel/config`（映射到 `/opt/config/user_config`），容器启动时会拉起 engine 并跟随日志。
- 默认启动 engine，容器内可运行作业：  
  `docker compose exec seatunnel ./bin/seatunnel.sh --config /opt/config/user_config/seatunnel.conf -m local`
- 示例配置：
  - `seatunnel/config/seatunnel.conf`：FakeSource -> Console。
  - `seatunnel/config/sqlserver_to_paimon.conf`：SQL Server CDC 多表（`ods_customers`、`ods_orders`）写入 MinIO 上的 Paimon，按 SeaTunnel 2.3.12 多表示例配置。
    - 依赖环境变量：`MSSQL_SA_PASSWORD`、`MINIO_ROOT_USER`、`MINIO_ROOT_PASSWORD`、`PAIMON_BUCKET`（默认 `paimon-warehouse`）。
    - 运行示例：`docker compose exec seatunnel ./bin/seatunnel.sh --config /opt/config/user_config/sqlserver_to_paimon.conf -m local`
    - 请先在 MinIO 创建桶 `${PAIMON_BUCKET}`（默认 `paimon-warehouse`），例如：
      - `docker compose exec minio mc alias set local http://localhost:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD`
      - `docker compose exec minio mc mb local/$PAIMON_BUCKET`


## 扩展思路
- 在 `app/main.py` 中添加业务路由；按需调整依赖
- 修改 `docker-compose.yml` 添加新的服务（如队列、前端、任务调度等）
- 使用 `.env` 覆盖默认变量并在 CI/CD 中引用
