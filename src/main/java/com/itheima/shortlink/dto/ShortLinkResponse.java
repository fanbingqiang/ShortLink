package com.itheima.shortlink.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class ShortLinkResponse {
    private String shortCode;
    private String shortUrl;
    private String longUrl;
}
