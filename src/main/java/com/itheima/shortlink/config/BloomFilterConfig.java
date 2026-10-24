package com.itheima.shortlink.config;

import com.google.common.hash.BloomFilter;
import com.google.common.hash.Funnels;
import com.itheima.shortlink.Mapper.ShortLinkMapper;
import com.itheima.shortlink.entity.ShortLink;
import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import java.nio.charset.Charset;
import java.util.List;

@Component
public class BloomFilterConfig {

    @Autowired
    private ShortLinkMapper shortLinkMapper;

    private BloomFilter<String> shortCodeBloomFilter;

    @PostConstruct
    public void init() {
        // 创建布隆过滤器，预期10000个元素，误判率0.01
        shortCodeBloomFilter = BloomFilter.create(
                Funnels.stringFunnel(Charset.defaultCharset()),
                10000,
                0.01
        );

        // 加载所有短码到布隆过滤器
        List<String> allShortCodes = shortLinkMapper.selectAllShortCodes();
        for (String shortCode : allShortCodes) {
            shortCodeBloomFilter.put(shortCode);
        }
    }

    public boolean mightContain(String shortCode) {
        return shortCodeBloomFilter.mightContain(shortCode);
    }

    public void put(String shortCode) {
        shortCodeBloomFilter.put(shortCode);
    }
}
