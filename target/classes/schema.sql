CREATE DATABASE IF NOT EXISTS short_link_db DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE short_link_db;

CREATE TABLE IF NOT EXISTS t_short_url (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    short_code VARCHAR(10) NOT NULL UNIQUE,
    long_url VARCHAR(500) NOT NULL,
    created_at DATETIME NOT NULL
);

CREATE INDEX idx_short_code ON t_short_url(short_code);
