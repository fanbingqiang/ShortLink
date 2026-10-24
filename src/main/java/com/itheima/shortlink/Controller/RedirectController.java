package com.itheima.shortlink.Controller;

import com.itheima.shortlink.Service.ShortLinkService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import java.net.URI;

@RestController
public class RedirectController {

    @Autowired
    private ShortLinkService shortLinkService;

    @GetMapping("/{shortCode:[a-zA-Z0-9]+}")
    public ResponseEntity<Void> redirect(@PathVariable String shortCode) {
        String longUrl = shortLinkService.getLongUrl(shortCode);
        if (longUrl == null) {
            return ResponseEntity.notFound().build();
        }
        HttpHeaders headers = new HttpHeaders();
        headers.setLocation(URI.create(longUrl));
        return new ResponseEntity<>(headers, HttpStatus.FOUND);
    }
}
