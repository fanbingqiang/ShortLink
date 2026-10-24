package com.itheima.shortlink.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableAsync;

import java.util.concurrent.Executor;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;

@Configuration
@EnableAsync
public class AsyncConfig {

    @Bean("cacheExecutor")
    public Executor cacheExecutor() {
        ThreadPoolExecutor executor = new ThreadPoolExecutor(
                4,                      // 核心线程数
                32,                     // 最大线程数
                60L,                    // 空闲线程存活时间
                TimeUnit.SECONDS,
                new LinkedBlockingQueue<>(1000),  // 任务队列
                new ThreadPoolExecutor.CallerRunsPolicy()  // 拒绝策略
        );
        executor.allowCoreThreadTimeOut(true);
        return executor;
    }
}
