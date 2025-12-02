FROM mcr.microsoft.com/mssql/server:2019-latest

ENV MSSQL_PID=Developer

USER root
RUN mkdir -p /docker-entrypoint-initdb.d && \
    chmod 755 /docker-entrypoint-initdb.d

# Install sqlcmd tooling for health checks and seed scripts
RUN apt-get update && \
    apt-get install -y curl apt-transport-https gnupg && \
    curl -s https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    curl -s https://packages.microsoft.com/config/ubuntu/20.04/prod.list > /etc/apt/sources.list.d/msprod.list && \
    apt-get update && \
    ACCEPT_EULA=Y apt-get install -y mssql-tools18 unixodbc-dev && \
    ln -s /opt/mssql-tools18/bin/sqlcmd /usr/bin/sqlcmd && \
    ln -s /opt/mssql-tools18/bin/bcp /usr/bin/bcp && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY ods_writer.sh /usr/local/bin/ods_writer.sh
COPY ods_seed.sql /docker-entrypoint-initdb.d/ods_seed.sql

RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/ods_writer.sh

USER mssql
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
