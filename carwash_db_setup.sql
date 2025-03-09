-- 1. Tablespace құру
CREATE TABLESPACE fast_space
    LOCATION '/path/to/fast/disk';

-- 2. Schema құру
CREATE SCHEMA carwash_schema;

-- 3. Кестелерді құру (carwash_schema ішінде басынан бастап)
-- clients кестесі
CREATE TABLE carwash_schema.clients (
    client_id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    phone VARCHAR(15) UNIQUE,
    email VARCHAR(100) UNIQUE,
    registration_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) TABLESPACE fast_space;

-- workers кестесі
CREATE TABLE carwash_schema.workers (
    worker_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    job_position VARCHAR(50) DEFAULT 'Қызметкер',
    salary INT CHECK (salary >= 0),
    department VARCHAR(50),
    schedule VARCHAR(100),
    phone_number VARCHAR(15),
    email VARCHAR(100)
) TABLESPACE fast_space;

-- service_providers кестесі
CREATE TABLE carwash_schema.service_providers (
    provider_id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    address VARCHAR(200),
    phone_number VARCHAR(15),
    country VARCHAR(50)
) TABLESPACE fast_space;

-- services кестесі
CREATE TABLE carwash_schema.services (
    service_id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    provider_id INT,
    price INT NOT NULL CHECK (price > 0),
    type VARCHAR(50),
    duration VARCHAR(50),
    discount VARCHAR(50),
    CONSTRAINT fk_services_provider FOREIGN KEY (provider_id)
        REFERENCES carwash_schema.service_providers(provider_id)
) TABLESPACE fast_space;

-- service_inventory кестесі
CREATE TABLE carwash_schema.service_inventory (
    inventory_id SERIAL PRIMARY KEY,
    service_id INT,
    worker_id INT,
    amount INT NOT NULL CHECK (amount >= 0),
    price INT NOT NULL CHECK (price >= 0),
    date_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total_cost INT NOT NULL CHECK (total_cost >= 0),
    CONSTRAINT fk_service_inventory_service FOREIGN KEY (service_id)
        REFERENCES carwash_schema.services(service_id),
    CONSTRAINT fk_service_inventory_worker FOREIGN KEY (worker_id)
        REFERENCES carwash_schema.workers(worker_id)
) TABLESPACE fast_space;

-- orders кестесі
CREATE TABLE carwash_schema.orders (
    order_id SERIAL PRIMARY KEY,
    service_id INT,
    worker_id INT,
    client_id INT,
    amount INT NOT NULL CHECK (amount > 0),
    price INT NOT NULL CHECK (price >= 0),
    total_price INT NOT NULL CHECK (total_price >= 0),
    date_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) NOT NULL DEFAULT 'Жаңа',
    CONSTRAINT fk_orders_service FOREIGN KEY (service_id)
        REFERENCES carwash_schema.services(service_id),
    CONSTRAINT fk_orders_worker FOREIGN KEY (worker_id)
        REFERENCES carwash_schema.workers(worker_id),
    CONSTRAINT fk_orders_client FOREIGN KEY (client_id)
        REFERENCES carwash_schema.clients(client_id)
) TABLESPACE fast_space;

-- payments кестесі
CREATE TABLE carwash_schema.payments (
    payment_id SERIAL PRIMARY KEY,
    order_id INT,
    amount DECIMAL(10, 2) NOT NULL CHECK (amount >= 0),
    payment_type VARCHAR(20) DEFAULT 'Қолма',
    payment_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_payments_order FOREIGN KEY (order_id)
        REFERENCES carwash_schema.orders(order_id)
) TABLESPACE fast_space;

-- 4. Индекстерді құру
CREATE INDEX idx_orders_client_id ON carwash_schema.orders(client_id) TABLESPACE fast_space;
CREATE INDEX idx_orders_worker_id ON carwash_schema.orders(worker_id) TABLESPACE fast_space;
CREATE INDEX idx_orders_service_id ON carwash_schema.orders(service_id) TABLESPACE fast_space;
CREATE INDEX idx_payments_order_id ON carwash_schema.payments(order_id) TABLESPACE fast_space;
CREATE INDEX idx_services_provider_id ON carwash_schema.services(provider_id) TABLESPACE fast_space;
CREATE INDEX idx_service_inventory_service_id ON carwash_schema.service_inventory(service_id) TABLESPACE fast_space;

-- 5. Көріністер құру
CREATE OR REPLACE VIEW carwash_schema.client_orders AS
SELECT
    c.client_id,
    c.full_name,
    o.order_id,
    o.date_time,
    o.status
FROM carwash_schema.clients c
JOIN carwash_schema.orders o ON c.client_id = o.client_id
WHERE o.status = 'Жаңа';

-- 6. Пайдаланушылар мен рөлдерді құру
CREATE ROLE admin_user WITH LOGIN PASSWORD 'admin123';
CREATE ROLE worker_user WITH LOGIN PASSWORD 'worker123';
CREATE ROLE client_user WITH LOGIN PASSWORD 'client123';

CREATE ROLE admin_role;
CREATE ROLE worker_role;
CREATE ROLE client_role;

GRANT ALL PRIVILEGES ON DATABASE carwash_db TO admin_role;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA carwash_schema TO worker_role;
GRANT SELECT ON ALL TABLES IN SCHEMA carwash_schema TO client_role;

GRANT admin_role TO admin_user;
GRANT worker_role TO worker_user;
GRANT client_role TO client_user;

-- 7. Деректерді генерациялау (1 миллион жол)
INSERT INTO carwash_schema.clients (full_name, phone, email, registration_date)
SELECT 'Client_' || i::text, '7' || lpad((1000000000 + i)::text, 10, '0'), 'client' || i || '@example.com', CURRENT_TIMESTAMP - (random() * interval '365 days')
FROM generate_series(1, 1000000) AS i;

INSERT INTO carwash_schema.workers (first_name, last_name, job_position, salary, department, schedule, phone_number, email)
SELECT 'WorkerFN_' || i::text, 'WorkerLN_' || i::text, CASE WHEN random() > 0.5 THEN 'Жуушы' ELSE 'Механик' END, floor(random() * 300000 + 100000)::int, CASE WHEN random() > 0.5 THEN 'Жуу бөлімі' ELSE 'Техникалық қызмет' END, '9:00-18:00', '7' || lpad((1000000000 + i)::text, 10, '0'), 'worker' || i || '@example.com'
FROM generate_series(1, 1000000) AS i;

INSERT INTO carwash_schema.service_providers (name, address, phone_number, country)
SELECT 'Provider_' || i::text, 'Address_' || i::text, '7' || lpad((1000000000 + i)::text, 10, '0'), CASE WHEN random() > 0.5 THEN 'Қазақстан' ELSE 'Ресей' END
FROM generate_series(1, 1000000) AS i;

INSERT INTO carwash_schema.services (name, provider_id, price, type, duration, discount)
SELECT 'Service_' || i::text, (i % 1000000 + 1)::int, floor(random() * 10000 + 1000)::int, CASE WHEN random() > 0.5 THEN 'Жуу' ELSE 'Техникалық' END, floor(random() * 120)::text || ' минут', floor(random() * 50)::text || '%'
FROM generate_series(1, 1000000) AS i;

INSERT INTO carwash_schema.service_inventory (service_id, worker_id, amount, price, date_time, total_cost)
SELECT (i % 1000000 + 1)::int, (i % 1000000 + 1)::int, floor(random() * 100 + 1)::int, floor(random() * 500 + 50)::int, CURRENT_TIMESTAMP - (random() * interval '365 days'), floor(random() * 10000 + 1000)::int
FROM generate_series(1, 1000000) AS i;

INSERT INTO carwash_schema.orders (service_id, worker_id, client_id, amount, price, total_price, date_time, status)
SELECT (i % 1000000 + 1)::int, (i % 1000000 + 1)::int, (i % 1000000 + 1)::int, floor(random() * 5 + 1)::int, floor(random() * 10000 + 1000)::int, floor(random() * 50000 + 5000)::int, CURRENT_TIMESTAMP - (random() * interval '365 days'), CASE WHEN random() > 0.7 THEN 'Орындалуда' ELSE 'Жаңа' END
FROM generate_series(1, 1000000) AS i;

INSERT INTO carwash_schema.payments (order_id, amount, payment_type, payment_date)
SELECT (i % 1000000 + 1)::int, random() * 50000 + 5000, CASE WHEN random() > 0.5 THEN 'Қолма' ELSE 'Карта' END, CURRENT_TIMESTAMP - (random() * interval '365 days')
FROM generate_series(1, 1000000) AS i;

-- 8. Шектеулер қосу
ALTER TABLE carwash_schema.orders
ADD CONSTRAINT positive_amount CHECK (amount > 0);

-- 9. Тестілік сұраныстар
-- 1. Толыққанды пайдаланушы ретінде тестілеу
CREATE TABLE carwash_schema.test_table (id SERIAL PRIMARY KEY, description VARCHAR(100));
INSERT INTO carwash_schema.test_table (description) VALUES ('Тест жазба');
DROP TABLE carwash_schema.test_table;

-- 2. JOIN сұранысы
SELECT c.full_name, o.order_id, s.name AS service_name, o.date_time, o.status
FROM carwash_schema.clients c
JOIN carwash_schema.orders o ON c.client_id = o.client_id
JOIN carwash_schema.services s ON o.service_id = s.service_id
WHERE o.date_time >= CURRENT_TIMESTAMP - INTERVAL '30 days'
LIMIT 10;

-- 3. GROUP BY және HAVING
SELECT s.name AS service_name, AVG(o.total_price) AS avg_total_price, COUNT(o.order_id) AS order_count
FROM carwash_schema.services s
JOIN carwash_schema.orders o ON s.service_id = o.service_id
GROUP BY s.name
HAVING AVG(o.total_price) > 5000
ORDER BY avg_total_price DESC
LIMIT 5;

-- 4. Индекстердің тиімділігін тексеру
EXPLAIN ANALYZE SELECT * FROM carwash_schema.orders WHERE client_id = 500000;

-- 5. Агрегаттық функциялар
SELECT SUM(amount) AS total_payments, AVG(amount) AS avg_payment, COUNT(*) AS payment_count
FROM carwash_schema.payments
WHERE payment_date >= CURRENT_TIMESTAMP - INTERVAL '90 days';

-- 6. WHERE фильтрациясы
SELECT o.order_id, c.full_name, s.name AS service_name, o.total_price, o.status
FROM carwash_schema.orders o
JOIN carwash_schema.clients c ON o.client_id = c.client_id
JOIN carwash_schema.services s ON o.service_id = s.service_id
WHERE o.total_price > 10000
AND o.date_time BETWEEN CURRENT_TIMESTAMP - INTERVAL '60 days' AND CURRENT_TIMESTAMP
AND o.status IN ('Жаңа', 'Орындалуда')
ORDER BY o.total_price DESC
LIMIT 10;