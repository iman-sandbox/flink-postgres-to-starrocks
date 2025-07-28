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
CREATE TABLE starrocks_test (
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
    'sink.properties.strip_outer_array' = 'true',
    'sink.properties.wait_for_commit' = 'true',
    'sink.semantic' = 'exactly-once',
    'sink.label-prefix' = 'postgres_test',
    'sink.version' = 'AUTO',
    'sink.wait-for-continue.timeout-ms' = '60000',
    'sink.connect.timeout-ms' = '30000',
    'sink.socket.timeout-ms' = '-1'
);

-- 3. Insert
INSERT INTO starrocks_test
SELECT id, name, description FROM postgres_test;


-- -- 2. Debug sink table to print output to stdout
-- CREATE TABLE debug_print_sink (
--     id INT,
--     name STRING,
--     description STRING
-- ) WITH (
--     'connector' = 'print'
-- );

-- -- 3. Insert CDC stream into the print sink
-- INSERT INTO debug_print_sink
-- SELECT id, name, description FROM postgres_test;