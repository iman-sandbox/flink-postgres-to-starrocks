#!/bin/bash
set -e

echo "📦 Stopping any existing containers..."
docker compose down --remove-orphans

echo "⬇️  Downloading required JARs..."
mkdir -p flink_libs

# PostgreSQL CDC connector
POSTGRES_CDC_JAR="flink_libs/flink-sql-connector-postgres-cdc-2.3.0.jar"
if [ ! -f "$POSTGRES_CDC_JAR" ]; then
  wget -O $POSTGRES_CDC_JAR https://repo1.maven.org/maven2/com/ververica/flink-sql-connector-postgres-cdc/2.3.0/flink-sql-connector-postgres-cdc-2.3.0.jar
fi

# StarRocks connector
STARROCKS_JAR="flink_libs/flink-connector-starrocks-1.2.6_flink-1.15.jar"
if [ ! -f "$STARROCKS_JAR" ]; then
  wget -O $STARROCKS_JAR https://repo1.maven.org/maven2/com/starrocks/flink-connector-starrocks/1.2.6_flink-1.15/flink-connector-starrocks-1.2.6_flink-1.15.jar
fi

# Flink Runtime from Cloudera
FLINK_DIST_JAR="flink_libs/flink-dist_2.12-1.16.2-csadh1.10.0.100.jar"
if [ ! -f "$FLINK_DIST_JAR" ]; then
  wget -O $FLINK_DIST_JAR https://repository.cloudera.com/repository/cloudera-repos/org/apache/flink/flink-dist_2.12/1.16.2-csadh1.10.0.100/flink-dist_2.12-1.16.2-csadh1.10.0.100.jar
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