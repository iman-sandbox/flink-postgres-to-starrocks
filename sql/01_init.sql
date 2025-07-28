-- 1. Source table
CREATE TABLE IF NOT EXISTS postgres_test (
    id INT,
    name STRING,
    description STRING,
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

-- 2. Sink table
CREATE TABLE IF NOT EXISTS starrocks_test (
    id INT,
    name STRING,
    description STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'starrocks',
    'jdbc-url' = 'jdbc:mysql://starrocks:9030/postgres?useSSL=false',
    'load-url' = 'starrocks:8040',
    'database-name' = 'postgres',
    'table-name' = 'test',
    'username' = 'root',
    'password' = '',
    'sink.buffer-flush.max-rows' = '64000',
    'sink.buffer-flush.interval-ms' = '2000',
    'sink.properties.format' = 'json',
    'sink.properties.strip_outer_array' = 'true'
);

-- 3. Insert
INSERT INTO starrocks_test
SELECT id, name, description FROM postgres_test;
