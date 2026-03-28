package com.example.shortlink.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import javax.sql.DataSource;
import java.sql.Connection;

@RestController
public class TestController {

    @Autowired
    private DataSource dataSource;

    @Autowired
    private RedisTemplate<String, String> redisTemplate;

    @GetMapping("/test/db")
    public String testDb() {
        try (Connection conn = dataSource.getConnection()) {
            return "Database connected: " + conn.getCatalog();
        } catch (Exception e) {
            return "Database error: " + e.getMessage();
        }
    }

    @GetMapping("/test/redis")
    public String testRedis() {
        try {
            redisTemplate.opsForValue().set("test", "ok");
            String value = redisTemplate.opsForValue().get("test");
            return "Redis test: " + value;
        } catch (Exception e) {
            return "Redis error: " + e.getMessage();
        }
    }

}
