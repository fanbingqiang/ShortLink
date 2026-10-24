package com.itheima.shortlink.Service.impl;

import com.google.common.util.concurrent.RateLimiter;
import com.itheima.shortlink.Mapper.ShortLinkMapper;
import com.itheima.shortlink.Service.ShortLinkService;
import com.itheima.shortlink.config.BloomFilterConfig;
import com.itheima.shortlink.entity.ShortLink;
import com.itheima.shortlink.util.ShortCodeGenerator;
import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;

@Service
public class ShortLinkServiceImpl implements ShortLinkService {

    private static final String REDIS_PREFIX = "short:link:";
    private static final String EMPTY_CACHE_PREFIX = "short:empty:";
    private static final long CACHE_EXPIRE_HOURS = 24;
    private static final long EMPTY_CACHE_EXPIRE_MINUTES = 5;
    private static final double ERROR_THRESHOLD = 0.5;
    private static final int CIRCUIT_BREAKER_THRESHOLD = 10;

    @Autowired
    private ShortLinkMapper shortLinkMapper;

    @Autowired(required = false)
    private StringRedisTemplate stringRedisTemplate;

    @Autowired
    private BloomFilterConfig bloomFilterConfig;

    private volatile boolean redisAvailable = true;
    private volatile boolean circuitBreakerOpen = false;
    private final AtomicInteger errorCount = new AtomicInteger(0);
    private final AtomicInteger totalCount = new AtomicInteger(0);

    // 限流器：每秒10个请求
    private final RateLimiter rateLimiter = RateLimiter.create(10.0);

    // 自定义线程池
    private final ExecutorService cacheExecutor = new ThreadPoolExecutor(
            4, 32, 60, TimeUnit.SECONDS,
            new LinkedBlockingQueue<>(10000),
            new ThreadFactory() {
                private int count = 0;
                @Override
                public Thread newThread(Runnable r) {
                    return new Thread(r, "cache-write-" + (++count));
                }
            },
            new ThreadPoolExecutor.DiscardPolicy()
    );

    @PostConstruct
    public void init() {
        checkRedisHealth();
        // 启动熔断器监控线程
        Executors.newSingleThreadScheduledExecutor().scheduleAtFixedRate(this::checkCircuitBreaker, 10, 10, TimeUnit.SECONDS);
    }

    @PreDestroy
    public void destroy() {
        cacheExecutor.shutdown();
    }

    private void checkRedisHealth() {
        if (stringRedisTemplate != null) {
            try {
                stringRedisTemplate.opsForValue().get("health:check");
                redisAvailable = true;
            } catch (Exception e) {
                redisAvailable = false;
            }
        }
    }

    private void checkCircuitBreaker() {
        int total = totalCount.getAndSet(0);
        int errors = errorCount.getAndSet(0);
        if (total > 0) {
            double errorRate = (double) errors / total;
            if (errorRate > ERROR_THRESHOLD && total > CIRCUIT_BREAKER_THRESHOLD) {
                circuitBreakerOpen = true;
            } else if (errorRate < 0.1) {
                circuitBreakerOpen = false;
            }
        }
    }

    @Override
    public ShortLink createShortLink(String longUrl) {
        // 限流检查
        if (!rateLimiter.tryAcquire()) {
            throw new RuntimeException("请求过于频繁，请稍后再试");
        }

        // 熔断检查
        if (circuitBreakerOpen) {
            throw new RuntimeException("系统繁忙，请稍后再试");
        }

        try {
            String shortCode = ShortCodeGenerator.generate(longUrl);
            ShortLink shortLink = new ShortLink();
            shortLink.setShortCode(shortCode);
            shortLink.setLongUrl(longUrl);
            shortLink.setCreatedAt(LocalDateTime.now());
            shortLinkMapper.insert(shortLink);

            // 添加到布隆过滤器
            bloomFilterConfig.put(shortCode);

            // 异步写入Redis
            if (redisAvailable && stringRedisTemplate != null) {
                cacheExecutor.execute(() -> {
                    try {
                        // 随机过期时间，防止雪崩
                        long expireHours = CACHE_EXPIRE_HOURS + ThreadLocalRandom.current().nextInt(0, 60);
                        stringRedisTemplate.opsForValue().set(
                                REDIS_PREFIX + shortCode,
                                longUrl,
                                expireHours,
                                TimeUnit.MINUTES
                        );
                    } catch (Exception e) {
                        // 忽略
                    }
                });
            }

            totalCount.incrementAndGet();
            return shortLink;
        } catch (Exception e) {
            errorCount.incrementAndGet();
            throw e;
        }
    }

    @Override
    public String getLongUrl(String shortCode) {
        // 限流检查
        if (!rateLimiter.tryAcquire()) {
            throw new RuntimeException("请求过于频繁，请稍后再试");
        }

        // 熔断检查
        if (circuitBreakerOpen) {
            throw new RuntimeException("系统繁忙，请稍后再试");
        }

        try {
            // 布隆过滤器判断
            if (!bloomFilterConfig.mightContain(shortCode)) {
                return null;
            }

            // 检查空缓存（防止缓存穿透）
            if (redisAvailable && stringRedisTemplate != null) {
                try {
                    String emptyKey = EMPTY_CACHE_PREFIX + shortCode;
                    String emptyValue = stringRedisTemplate.opsForValue().get(emptyKey);
                    if ("EMPTY".equals(emptyValue)) {
                        return null;
                    }
                } catch (Exception e) {
                    // 忽略
                }
            }

            // 尝试从Redis读取
            if (redisAvailable && stringRedisTemplate != null) {
                try {
                    String cacheKey = REDIS_PREFIX + shortCode;
                    String cachedUrl = stringRedisTemplate.opsForValue().get(cacheKey);
                    if (cachedUrl != null) {
                        totalCount.incrementAndGet();
                        return cachedUrl;
                    }
                } catch (Exception e) {
                    redisAvailable = false;
                }
            }

            // 从数据库查询（带互斥锁防止缓存击穿）
            String longUrl = queryWithMutex(shortCode);

            if (longUrl != null) {
                totalCount.incrementAndGet();
            } else {
                // 缓存空对象，防止穿透
                if (redisAvailable && stringRedisTemplate != null) {
                    cacheExecutor.execute(() -> {
                        try {
                            stringRedisTemplate.opsForValue().set(
                                    EMPTY_CACHE_PREFIX + shortCode,
                                    "EMPTY",
                                    EMPTY_CACHE_EXPIRE_MINUTES,
                                    TimeUnit.MINUTES
                            );
                        } catch (Exception e) {
                            // 忽略
                        }
                    });
                }
            }
            return longUrl;
        } catch (Exception e) {
            errorCount.incrementAndGet();
            throw e;
        }
    }

    // 互斥锁查询，防止缓存击穿
    private final ConcurrentHashMap<String, Object> locks = new ConcurrentHashMap<>();

    private String queryWithMutex(String shortCode) {
        Object lock = locks.computeIfAbsent(shortCode, k -> new Object());
        synchronized (lock) {
            // 双重检查
            if (redisAvailable && stringRedisTemplate != null) {
                try {
                    String cachedUrl = stringRedisTemplate.opsForValue().get(REDIS_PREFIX + shortCode);
                    if (cachedUrl != null) {
                        return cachedUrl;
                    }
                } catch (Exception e) {
                    // 忽略
                }
            }

            // 查询数据库
            String longUrl = shortLinkMapper.findByShortCode(shortCode)
                    .map(ShortLink::getLongUrl)
                    .orElse(null);

            // 异步写入Redis
            if (longUrl != null && redisAvailable && stringRedisTemplate != null) {
                cacheExecutor.execute(() -> {
                    try {
                        long expireHours = CACHE_EXPIRE_HOURS + ThreadLocalRandom.current().nextInt(0, 60);
                        stringRedisTemplate.opsForValue().set(
                                REDIS_PREFIX + shortCode,
                                longUrl,
                                expireHours,
                                TimeUnit.MINUTES
                        );
                    } catch (Exception e) {
                        // 忽略
                    }
                });
            }

            return longUrl;
        }
    }
}
