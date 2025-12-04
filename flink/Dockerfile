FROM flink:1.18

# Install Python and PyFlink per Flink docs
RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 python3-pip python3-venv \
    && python3 -m pip install --no-cache-dir apache-flink==1.18.0 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV PYFLINK_CLIENT_EXECUTABLE=python3
