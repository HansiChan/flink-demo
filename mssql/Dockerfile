FROM mcr.microsoft.com/mssql/server:2019-latest

ENV MSSQL_PID=Developer

USER root
RUN mkdir -p /docker-entrypoint-initdb.d && \
    chmod 755 /docker-entrypoint-initdb.d

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY ods_writer.sh /usr/local/bin/ods_writer.sh
COPY ods_seed.sql /docker-entrypoint-initdb.d/ods_seed.sql

RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/ods_writer.sh

USER mssql
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
