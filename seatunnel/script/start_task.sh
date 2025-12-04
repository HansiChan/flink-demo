docker run --name seatunnel_client \
    --network flink-demo_demo \
    -e ST_DOCKER_MEMBER_LIST=172.16.0.2:5801 \
    --rm \
    -v ./seatunnel/config:/opt/seatunnel/config/user_config \
    apache/seatunnel \
    ./bin/seatunnel.sh -c /opt/seatunnel/config/user_config/sqlserver_to_paimon.conf