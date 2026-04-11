CREATE TABLE IF NOT EXISTS `short_link` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `long_url` VARCHAR(2048) NOT NULL COMMENT '原始长链接',
    `short_code` VARCHAR(16) DEFAULT NULL COMMENT '短链接码',
    `status` TINYINT DEFAULT 1 COMMENT '状态：1-正常 0-禁用',
    `visit_count` BIGINT DEFAULT 0 COMMENT '访问次数',
    `last_visit_time` DATETIME DEFAULT NULL COMMENT '最后访问时间',
    `gmt_create` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `gmt_modified` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_short_code` (`short_code`),
    KEY `idx_long_url` (`long_url`(255))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='短链接表';