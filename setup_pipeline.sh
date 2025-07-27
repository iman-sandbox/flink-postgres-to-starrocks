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
    description TEXT,
    age INT,
    balance NUMERIC,
    active BOOLEAN,
    created_at TIMESTAMP,
    updated_date DATE,
    rating DOUBLE PRECISION,
    big_value BIGINT,
    small_value SMALLINT,
    byte_value BYTEA,
    uuid_value UUID,
    inet_value INET,
    json_value JSONB,
    tags TEXT[],
    status VARCHAR(50),
    interval_value INTERVAL
);
DO $$
BEGIN
  FOR i IN 1..5 LOOP
    INSERT INTO test (
        name, description, age, balance, active, created_at, updated_date,
        rating, big_value, small_value, byte_value, uuid_value, inet_value,
        json_value, tags, status, interval_value
    )
    VALUES (
        'Name_' || i,
        'Description for record ' || i,
        floor(random() * 100)::int,
        round((random() * 10000)::numeric, 2),
        (random() > 0.5),
        now() - (random() * interval '30 days'),
        current_date - (random() * 365)::int,
        random() * 5,
        (random() * 100000)::bigint,
        (random() * 100)::smallint,
        decode(md5(random()::text), 'hex'),
        gen_random_uuid(),
        ('192.168.0.' || (random() * 255)::int)::inet,
        json_build_object('key', 'value_' || i),
        ARRAY['tag1', 'tag2', 'tag' || i],
        chr(65 + (random()*25)::int),
        (random() * interval '10 days')::interval
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

CREATE TABLE IF NOT EXISTS test (
    id INT,
    name VARCHAR(100),
    description STRING,
    age INT,
    balance DECIMAL(38, 10),
    active BOOLEAN,
    created_at DATETIME,
    updated_date DATE,
    rating DOUBLE,
    big_value BIGINT,
    small_value SMALLINT,
    byte_value STRING,
    uuid_value STRING,
    inet_value STRING,
    json_value STRING,
    tags ARRAY<STRING>,
    status VARCHAR(50),
    interval_value STRING
)
DUPLICATE KEY(id)
DISTRIBUTED BY HASH(id) BUCKETS 8
PROPERTIES (
    "replication_num" = "1"
);
EOF

echo "✅ StarRocks schema initialized."
echo "🚀 Loading Flink SQL job from sql/01_init.sql..."
docker exec jobmanager ./bin/sql-client.sh -f /opt/flink/sql/01_init.sql

echo "✅ Flink CDC pipeline started."
