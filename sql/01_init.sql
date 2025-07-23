-- ✅ CDC Source: embedded Postgres container
CREATE TABLE embedded_table (
  id INT,
  name STRING,
  updated_at TIMESTAMP(3),
  PRIMARY KEY (id) NOT ENFORCED
) WITH (
  'connector' = 'postgres-cdc',
  'hostname' = 'postgres1',
  'port' = '5432',
  'username' = 'postgres',
  'password' = 'postgres',
  'database-name' = 'test',
  'schema-name' = 'public',
  'table-name' = 'your_table_name',  -- 🔁 Replace with actual table name
  'decoding.plugin.name' = 'pgoutput',
  'scan.incremental.snapshot.enabled' = 'true'
);

-- ✅ Debug Sink
CREATE TABLE print_sink (
  id INT,
  name STRING,
  updated_at TIMESTAMP(3)
) WITH (
  'connector' = 'print'
);

-- ✅ StarRocks Sink
CREATE TABLE starrocks_sink (
  id INT,
  name STRING,
  updated_at TIMESTAMP(3),
  PRIMARY KEY (id) NOT ENFORCED
) WITH (
  'connector' = 'starrocks',
  'jdbc-url' = 'jdbc:mysql://starrocks-fe:9030',
  'load-url' = 'http://starrocks-fe:8030',
  'username' = 'root',
  'password' = '',
  'database-name' = 'test',
  'table-name' = 'your_table_name'
);

-- ✅ Stream changes to StarRocks
INSERT INTO starrocks_sink
SELECT * FROM embedded_table;

-- ✅ Stream to print sink
INSERT INTO print_sink
SELECT * FROM embedded_table;