#!/bin/bash
set -e

echo "💡 Launching Flink SQL Client..."

docker exec -it flink-postgres-to-storrocks-jobmanager ./bin/sql-client.sh \
  --library /opt/flink/lib-extra \
  "$@"
