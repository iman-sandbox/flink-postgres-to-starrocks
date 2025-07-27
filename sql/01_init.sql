-- 1. Source Table: Read all changes from Postgres with Flink CDC
CREATE TABLE postgres_test (
    id INT,
    name STRING,
    description STRING,
    age INT,
    balance DECIMAL(10,2),
    active BOOLEAN,
    created_at TIMESTAMP(3),
    updated_date DATE,
    rating FLOAT,
    big_value BIGINT,
    small_value SMALLINT,
    byte_value BYTES,
    uuid_value STRING,
    inet_value STRING,
    `json_value` STRING,
    tags STRING,
    status STRING,
    interval_value STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'postgres-cdc',
    'hostname' = 'postgres',
    'port' = '5432',
    'username' = 'postgres',
    'password' = 'postgres',
    'database-name' = 'postgres',
    'schema-name' = 'public',
    'table-name' = 'test',
    'slot.name' = 'cdc_slot_test',
    'decoding.plugin.name' = 'pgoutput',
    'scan.startup.mode' = 'initial'
);

-- 2. Sink Table: StarRocks target table to write all CDC changes
CREATE TABLE starrocks_test (
    id INT,
    name STRING,
    description STRING,
    age INT,
    balance DECIMAL(10,2),
    active BOOLEAN,
    created_at TIMESTAMP,
    updated_date DATE,
    rating DOUBLE,
    big_value BIGINT,
    small_value SMALLINT,
    byte_value STRING,
    uuid_value STRING,
    inet_value STRING,
    `json_value` STRING,
    tags STRING,
    status STRING,
    interval_value STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'starrocks',
    'jdbc-url' = 'jdbc:mysql://starrocks:9030/postgres?useSSL=false',
    'load-url' = 'starrocks:8030',
    'database-name' = 'postgres',
    'table-name' = 'test',
    'username' = 'root',
    'password' = '',
    'sink.buffer-flush.max-rows' = '64000',
    'sink.buffer-flush.interval-ms' = '2000',
    'sink.properties.format' = 'json',
    'sink.properties.strip_outer_array' = 'true'
);

-- 3. Stream changes from Postgres (CDC) to StarRocks (Sink)
INSERT INTO starrocks_test
SELECT
    id,
    name,
    description,
    age,
    balance,
    active,
    created_at,
    updated_date,
    CAST(rating AS DOUBLE),
    big_value,
    small_value,
    CAST(byte_value AS STRING),
    uuid_value,
    inet_value,
    CAST(`json_value` AS STRING),
    tags,
    status,
    CAST(interval_value AS STRING)
FROM postgres_test;
