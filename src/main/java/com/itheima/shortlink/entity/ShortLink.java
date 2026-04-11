package com.itheima.shortlink.entity;

import lombok.Data;
import java.time.LocalDateTime;

@Data
public class ShortLink {
    private Long id;
    private String shortCode;
    private String longUrl;
    private LocalDateTime createdAt;
}
