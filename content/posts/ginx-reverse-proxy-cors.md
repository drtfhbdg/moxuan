---
title: "Nginx 反向代理踩坑：跨域资源共享 (CORS) 报错怎么破"
date: 2024-07-09T20:10:00+08:00
draft: false
tags: ["Nginx", "跨域", "排障"]
categories: ["服务器运维"]
---

今天在给一个前后端分离的项目配置 Nginx 反代时，前端控制台一片红，全都是 `CORS Error`。

分析了一下，前端域名和后端接口的域名不一样，浏览器处于安全机制把请求拦截了。

直接在 Nginx 的配置文件里给接口加上允许跨域的 Header，改完重新 `nginx -s reload`。

```nginx
location /api/ {
    proxy_pass [http://127.0.0.1:8080/](http://127.0.0.1:8080/);
    add_header 'Access-Control-Allow-Origin' '*';
    add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS';
    add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization';
}
```

 搞定收工。配置服务器就是这样，有时候卡了一小时的问题，其实就是少写了两行配置项。 