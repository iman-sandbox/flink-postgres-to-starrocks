#!/bin/bash

docker compose down --remove-orphans
# docker system prune -af
# docker volume prune -f

# Ensure external network exists
if ! docker network inspect flink-net >/dev/null 2>&1; then
    echo "🔗 Creating external network 'flink-net'..."
    docker network create flink-net
fi

echo "⬇️  Downloading required JARs..."
mkdir -p flink_libs

# PostgreSQL CDC connector for Flink 1.17
POSTGRES_CDC_JAR="flink_libs/flink-sql-connector-postgres-cdc-2.4.0.jar"
if [ ! -f "$POSTGRES_CDC_JAR" ]; then
  wget -O "$POSTGRES_CDC_JAR" \
    https://repo1.maven.org/maven2/com/ververica/flink-sql-connector-postgres-cdc/2.4.0/flink-sql-connector-postgres-cdc-2.4.0.jar
fi

# StarRocks connector for Flink 1.17
STARROCKS_JAR="flink_libs/flink-connector-starrocks-1.2.10_flink-1.17.jar"
if [ ! -f "$STARROCKS_JAR" ]; then
  wget -O "$STARROCKS_JAR" \
    https://repo1.maven.org/maven2/com/starrocks/flink-connector-starrocks/1.2.10_flink-1.17/flink-connector-starrocks-1.2.10_flink-1.17.jar
fi

echo "✅ All connectors and runtime downloaded to ./flink_libs"

mkdir -p flink_conf
cat > flink_conf/flink-conf.yaml <<EOF
jobmanager.memory.process.size: 1024m
taskmanager.memory.process.size: 1024m
taskmanager.numberOfTaskSlots: 2
execution.checkpointing.interval: 10000
EOF

# ... after FE startup:
# Instead of `ADMIN SET FRONTEND CONFIG...`, run either:
# Option A (if sql support):
docker exec -i starrocks_fe mysql -uroot -e "SET GLOBAL stream_load_default_timeout_second = 600;"
# Option B (edit fe.conf before startup):
# Add line: stream_load_default_timeout_second=600

# Then restart FE if using fe.conf


echo "🔁 Starting Postgres for WAL/CDC slot cleanup..."
docker compose up -d postgres

echo "⏳ Waiting for Postgres to be ready..."
RETRIES=20
until docker exec postgres pg_isready -U postgres > /dev/null 2>&1; do
  sleep 1
  RETRIES=$((RETRIES-1))
  if [ "$RETRIES" -le 0 ]; then
    echo "❌ Postgres did not become ready in time."
    exit 1
  fi
done

echo "🧹 Dropping old CDC replication slot if exists..."
docker exec postgres psql -U postgres -d postgres -c "SELECT pg_drop_replication_slot('cdc_slot_test');" 2>/dev/null || true

echo "🛑 Stopping only Postgres to clear state..."
docker compose stop postgres

echo "🔁 (Re)Starting all containers..."
docker compose pull || true
docker compose up -d

echo "⏳ Waiting for Flink JobManager to be ready..."
RETRIES=30
until curl -s http://localhost:8081/overview > /dev/null; do
  sleep 2
  RETRIES=$((RETRIES-1))
  if [ "$RETRIES" -le 0 ]; then
    echo "❌ Flink JobManager did not become ready in time."
    exit 1
  fi
done
echo "✅ Flink JobManager is ready at http://localhost:8081"

echo "⏳ Waiting for StarRocks FE to be ready..."
RETRIES=10
until docker exec starrocks mysql -uroot -h127.0.0.1 -P9030 -e "SHOW DATABASES;" &>/dev/null; do
  sleep 2
  RETRIES=$((RETRIES-1))
  if [ "$RETRIES" -le 0 ]; then
    echo "❌ StarRocks FE did not become ready in time."
    exit 1
  fi
done
echo "✅ StarRocks FE is ready."

echo "⏳ Waiting for StarRocks BE to be ready..."
sleep 10  # Usually enough for BE after FE

echo "📄 Creating test table and inserting data in Postgres..."

docker exec -i postgres bash -c "cat > /init_test_table.sql" <<'EOF'
CREATE EXTENSION IF NOT EXISTS pgcrypto;
DROP TABLE IF EXISTS test;
CREATE TABLE IF NOT EXISTS test (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    description TEXT
);
ALTER TABLE test REPLICA IDENTITY FULL;
DO $$
BEGIN
  FOR i IN 1..10 LOOP
    INSERT INTO test (
        name, description
    )
    VALUES (
        'Name_' || i,
        'Description for record ' || i
    );
  END LOOP;
END $$;
SELECT * FROM test;
EOF


docker exec postgres psql -U postgres -d postgres -f /init_test_table.sql

echo "📝 Creating StarRocks database and table 'test'..."
docker exec -i starrocks mysql -uroot -h127.0.0.1 -P9030 <<EOF
CREATE DATABASE IF NOT EXISTS postgres;

USE postgres;

DROP TABLE IF EXISTS test;

CREATE TABLE test (
  id INT,
  name VARCHAR(100),
  description VARCHAR(255)
)
ENGINE=OLAP
PRIMARY KEY(id)
DISTRIBUTED BY HASH(id) BUCKETS 1
PROPERTIES (
  "replication_num" = "1"
);

EOF

echo "✅ StarRocks schema initialized."
echo "🚀 Loading Flink SQL job from sql/01_init.sql..."
docker exec jobmanager ./bin/sql-client.sh -f /opt/flink/sql/01_init.sql

echo "✅ Flink CDC pipeline started."
