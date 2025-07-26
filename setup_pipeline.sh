#!/bin/bash
set -e

echo "📦 Stopping any existing containers..."
docker compose down --remove-orphans

echo "⬇️  Downloading required JARs..."
mkdir -p flink_libs

# PostgreSQL CDC connector for Flink 1.17
POSTGRES_CDC_JAR="flink_libs/flink-sql-connector-postgres-cdc-3.0.0.jar"
if [ ! -f "$POSTGRES_CDC_JAR" ]; then
  wget -O "$POSTGRES_CDC_JAR" \
    https://repo1.maven.org/maven2/com/ververica/flink-sql-connector-postgres-cdc/3.0.0/flink-sql-connector-postgres-cdc-3.0.0.jar
fi

# StarRocks connector for Flink 1.17
STARROCKS_JAR="flink_libs/flink-connector-starrocks-1.2.11_flink-1.17.jar"
if [ ! -f "$STARROCKS_JAR" ]; then
  wget -O "$STARROCKS_JAR" \
    https://repo1.maven.org/maven2/com/starrocks/flink-connector-starrocks/1.2.11_flink-1.17/flink-connector-starrocks-1.2.11_flink-1.17.jar
fi

echo "✅ All connectors and runtime downloaded to ./flink_libs"
echo "🔁 Rebuilding and starting containers..."
docker compose build
docker compose up -d

echo "⏳ Waiting for Flink JobManager to be ready..."
until curl -s http://localhost:8081 > /dev/null; do
  echo "⏳ Still waiting for JobManager container..."
  sleep 2
done

echo "✅ Flink JobManager is ready at http://localhost:8081"

# Wait for StarRocks FE to be ready (port 9030)
echo "⏳ Waiting for StarRocks FE to be ready..."
until docker exec starrocks mysql -h 127.0.0.1 -P 9030 -uroot -e "SHOW DATABASES;" >/dev/null 2>&1; do
  echo "⏳ Still waiting for StarRocks FE..."
  sleep 3
done

echo "✅ StarRocks FE is ready. Initializing schema..."

# Wait for at least one BE to be ready (Alive = true)
echo "⏳ Waiting for StarRocks BE to be ready..."
until docker exec starrocks mysql -h 127.0.0.1 -P 9030 -uroot -N -e 'SHOW BACKENDS;' | grep -q '\btrue\b'; do
  echo "⏳ Still waiting for StarRocks BE..."
  sleep 3
done

echo "📄 Creating test table and inserting data..."

docker exec -i postgres bash -c "cat > /init_test_table.sql" <<'EOF'
CREATE EXTENSION IF NOT EXISTS pgcrypto;
DROP TABLE IF EXISTS test_data_types;
CREATE TABLE test_data_types (
    id SERIAL PRIMARY KEY,
    name TEXT,
    description VARCHAR(255),
    age INTEGER,
    balance NUMERIC(10,2),
    active BOOLEAN,
    created_at TIMESTAMP,
    updated_date DATE,
    rating REAL,
    big_value BIGINT,
    small_value SMALLINT,
    byte_value BYTEA,
    uuid_value UUID,
    inet_value INET,
    json_value JSON,
    tags TEXT[],
    status CHAR(1),
    interval_value INTERVAL
);
DO $$
BEGIN
  FOR i IN 1..50 LOOP
    INSERT INTO test_data_types (
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
SELECT * FROM test_data_types;
EOF

echo "📝 Running SQL initialization..."
docker exec -u postgres postgres psql -U postgres -f /init_test_table.sql

# Create database and table if needed
docker exec starrocks mysql -h 127.0.0.1 -P 9030 -uroot -e "
CREATE DATABASE IF NOT EXISTS postgres;
USE postgres;
CREATE TABLE IF NOT EXISTS test_data_types (
    id INT NOT NULL,
    name VARCHAR(255),
    updated_date DATE
)
PRIMARY KEY (id)
DISTRIBUTED BY HASH(id) BUCKETS 10
PROPERTIES ('replication_num' = '1');
"

echo "✅ StarRocks schema initialized."

# Submit Flink SQL job
echo "🚀 Loading Flink SQL job from sql/01_init.sql..."
docker exec jobmanager ./bin/sql-client.sh \
  --library /opt/flink/lib-extra \
  -f /opt/flink/sql/01_init.sql
