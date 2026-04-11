package com.itheima.shortlink.Service;

import com.itheima.shortlink.entity.ShortLink;

public interface ShortLinkService {
    ShortLink createShortLink(String longUrl);
    String getLongUrl(String shortCode);
}
