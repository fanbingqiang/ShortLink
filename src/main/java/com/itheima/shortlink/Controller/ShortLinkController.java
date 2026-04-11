package com.itheima.shortlink.Controller;

import com.itheima.shortlink.Service.ShortLinkService;
import com.itheima.shortlink.dto.ApiResponse;
import com.itheima.shortlink.dto.CreateShortLinkRequest;
import com.itheima.shortlink.dto.ShortLinkResponse;
import com.itheima.shortlink.entity.ShortLink;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/short-link")
public class ShortLinkController {

    @Autowired
    private ShortLinkService shortLinkService;

    @Value("${short-link.base-url:http://localhost:8080/}")
    private String baseUrl;

    @PostMapping("/create")
    public ApiResponse<ShortLinkResponse> createShortLink(@RequestBody CreateShortLinkRequest request) {
        if (request.getLongUrl() == null || request.getLongUrl().isEmpty()) {
            return ApiResponse.error("longUrl is required");
        }
        ShortLink shortLink = shortLinkService.createShortLink(request.getLongUrl());
        ShortLinkResponse response = new ShortLinkResponse(
                shortLink.getShortCode(),
                baseUrl + shortLink.getShortCode(),
                shortLink.getLongUrl()
        );
        return ApiResponse.success(response);
    }

    @GetMapping("/{shortCode}")
    public ApiResponse<String> getLongUrl(@PathVariable String shortCode) {
        String longUrl = shortLinkService.getLongUrl(shortCode);
        if (longUrl == null) {
            return ApiResponse.error("Short link not found");
        }
        return ApiResponse.success(longUrl);
    }
}
