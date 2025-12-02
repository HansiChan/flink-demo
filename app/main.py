import os
from contextlib import closing

import psycopg2
import redis
from fastapi import FastAPI, HTTPException

app = FastAPI(title="Demo Compose API")

DATABASE_URL = os.getenv(
    "DATABASE_URL", "postgresql://demo:demo@db:5432/demo"
)
REDIS_URL = os.getenv("REDIS_URL", "redis://redis:6379/0")

r = redis.Redis.from_url(REDIS_URL, decode_responses=True)


@app.get("/")
def read_root():
    return {"message": "Hello from docker-compose skeleton"}


@app.get("/health")
def healthcheck():
    try:
        with closing(psycopg2.connect(DATABASE_URL)) as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1;")
                _ = cur.fetchone()
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Postgres check failed: {exc}")

    try:
        r.ping()
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Redis check failed: {exc}")

    return {"status": "ok"}
