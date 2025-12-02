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
- Redis: localhost:6379
- SQL Server: localhost:1433（SA 密码见 `.env`，默认 `YourStrong!Passw0rd`）

## 常用操作
- 查看服务日志：`docker compose logs -f api`（或 `db` / `redis`）
- 停止并清理：`docker compose down -v`

## SQL Server ODS 说明
- `mssql/ods_seed.sql` 会在容器启动时创建 `ods` 数据库并写入演示表：`ods_customers` 与 `ods_orders`（含外键，可 join），作为后续 ETL 的 ODS 数据源。
- 如需调整种子数据或表结构，可修改 `mssql/ods_seed.sql` 并重建镜像：`docker compose build mssql && docker compose up -d`.

### 连续写入配置（实时模拟 ODS 数据）
- 默认开启连续写入 `ods_orders`，可通过 `.env` 调参：
  - `ODS_WRITE_ENABLED`：是否开启连续写入（默认 `true`）
  - `ODS_WRITE_INTERVAL_SECONDS`：写入间隔秒数（默认 `2`）
  - `ODS_WRITE_BATCH_SIZE`：每次写入的行数（默认 `1`）
  - `ODS_WRITE_MAX_ROWS`：最多写入多少行后停止（默认 `0` 表示不限制）
- 写入脚本位于 `mssql/ods_writer.sh`，由 `entrypoint.sh` 启动；如需更改逻辑可修改脚本后重建镜像。

## 扩展思路
- 在 `app/main.py` 中添加业务路由；按需调整依赖
- 修改 `docker-compose.yml` 添加新的服务（如队列、前端、任务调度等）
- 使用 `.env` 覆盖默认变量并在 CI/CD 中引用
