FROM flink:1.20.2

# Install Python + venv per Flink Python docs
RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 python3-pip python3-venv \
    && python3 -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir apache-flink==1.20.2 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="/opt/venv/bin:${PATH}"
ENV PYFLINK_CLIENT_EXECUTABLE=/opt/venv/bin/python3
