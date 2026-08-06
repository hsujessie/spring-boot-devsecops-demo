package com.example.demo.rest;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class FunRestController {

    @Autowired
    private StringRedisTemplate redisTemplate;

    @GetMapping("/")
    public String sayHello() {
        Long views = redisTemplate.opsForValue().increment("page_views");
        return "本站累計造訪次數：" + views;
    }

}