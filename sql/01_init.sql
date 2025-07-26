-- ------------------------------------------------------------------
-- 1. Source Table: Read all changes from Postgres with Flink CDC
-- ------------------------------------------------------------------
CREATE TABLE postgres_test_data_types (
    id INT,
    name STRING,
    updated_date DATE,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'postgres-cdc',
    'hostname' = 'postgres',
    'port' = '5432',
    'username' = 'postgres',
    'password' = 'postgres',
    'database-name' = 'postgres',
    'schema-name' = 'public',
    'table-name' = 'test_data_types',
    'slot.name' = 'cdc_slot_test_data_types',
    'decoding.plugin.name' = 'pgoutput'
);

-- ------------------------------------------------------------------
-- 2. Sink Table: StarRocks target table to write all CDC changes
-- ------------------------------------------------------------------
CREATE TABLE starrocks_test_data_types (
    id INT,
    name STRING,
    updated_date DATE,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'starrocks',
    'jdbc-url' = 'jdbc:mysql://starrocks:9030/postgres',
    'load-url' = 'starrocks:8030',
    'database-name' = 'postgres',
    'table-name' = 'test_data_types',
    'username' = 'root',
    'password' = '',
    'sink.buffer-flush.max-rows' = '64000',
    'sink.buffer-flush.interval-ms' = '2000'
);

-- ------------------------------------------------------------------
-- 3. Stream changes from Postgres (CDC) to StarRocks (Sink)
-- ------------------------------------------------------------------
INSERT INTO starrocks_test_data_types
SELECT id, name, updated_date
FROM postgres_test_data_types;
