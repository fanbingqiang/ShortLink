package com.itheima.shortlink.Mapper;

import com.itheima.shortlink.entity.ShortLink;
import org.apache.ibatis.annotations.*;

import java.util.Optional;

@Mapper
public interface ShortLinkMapper {

    @Select("SELECT id, short_code, long_url, created_at FROM t_short_url WHERE short_code = #{shortCode}")
    @Results({
            @Result(property = "shortCode", column = "short_code"),
            @Result(property = "longUrl", column = "long_url"),
            @Result(property = "createdAt", column = "created_at")
    })
    Optional<ShortLink> findByShortCode(String shortCode);

    @Insert("INSERT INTO t_short_url(short_code, long_url, created_at) VALUES(#{shortCode}, #{longUrl}, #{createdAt})")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insert(ShortLink shortLink);

    @Select("SELECT id, short_code, long_url, created_at FROM t_short_url WHERE id = #{id}")
    @Results({
            @Result(property = "shortCode", column = "short_code"),
            @Result(property = "longUrl", column = "long_url"),
            @Result(property = "createdAt", column = "created_at")
    })
    Optional<ShortLink> findById(Long id);
}
