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
