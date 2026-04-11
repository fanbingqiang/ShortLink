package com.itheima.shortlink.Service.impl;

import com.itheima.shortlink.Mapper.ShortLinkMapper;
import com.itheima.shortlink.Service.ShortLinkService;
import com.itheima.shortlink.entity.ShortLink;
import com.itheima.shortlink.util.ShortCodeGenerator;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.concurrent.TimeUnit;

@Service
public class ShortLinkServiceImpl implements ShortLinkService {

    private static final String REDIS_PREFIX = "short:link:";
    private static final long CACHE_EXPIRE_HOURS = 24;

    @Autowired
    private ShortLinkMapper shortLinkMapper;

    @Autowired
    private StringRedisTemplate stringRedisTemplate;

    @Override
    public ShortLink createShortLink(String longUrl) {
        String shortCode = ShortCodeGenerator.generate(longUrl);
        ShortLink shortLink = new ShortLink();
        shortLink.setShortCode(shortCode);
        shortLink.setLongUrl(longUrl);
        shortLink.setCreatedAt(LocalDateTime.now());
        shortLinkMapper.insert(shortLink);
        stringRedisTemplate.opsForValue().set(
                REDIS_PREFIX + shortCode,
                longUrl,
                CACHE_EXPIRE_HOURS,
                TimeUnit.HOURS
        );
        return shortLink;
    }

    @Override
    public String getLongUrl(String shortCode) {
        String cacheKey = REDIS_PREFIX + shortCode;
        String cachedUrl = stringRedisTemplate.opsForValue().get(cacheKey);
        if (cachedUrl != null) {
            return cachedUrl;
        }
        String longUrl = shortLinkMapper.findByShortCode(shortCode)
                .map(ShortLink::getLongUrl)
                .orElse(null);
        if (longUrl != null) {
            stringRedisTemplate.opsForValue().set(
                    cacheKey,
                    longUrl,
                    CACHE_EXPIRE_HOURS,
                    TimeUnit.HOURS
            );
        }
        return longUrl;
    }
}
