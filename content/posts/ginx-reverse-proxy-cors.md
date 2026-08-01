---
title: "Nginx 反向代理踩坑：跨域资源共享 (CORS) 报错怎么破"
date: 2024-08-15T20:10:00+08:00
draft: false
tags: ["Nginx", "跨域", "排障"]
categories: ["服务器运维"]
description: "记录一次前后端分离项目中 Nginx 反向代理遇到 CORS 跨域报错的排查和解决过程。"
---

今天在给一个前后端分离的项目配置 Nginx 反代时，前端控制台一片红，全都是 `CORS Error`。前端的请求发到了 `api.example.com`，而后端服务跑在 `localhost:8080`，域名不一样，浏览器的同源策略就把请求拦截了。

其实 CORS 问题算是前后端分离项目里的老面孔了。解决思路一般有两种：要么让后端加上 CORS Header，要么在 Nginx 这一层统一处理。我这次选择在 Nginx 里解决，因为后端服务可能不止一个，统一在网关层管理跨域更方便。

## 什么是 CORS

CORS 全称 Cross-Origin Resource Sharing，跨域资源共享。浏览器出于安全考虑，会限制从一个域名加载的网页去请求另一个域名的资源。这种限制叫做"同源策略"。

两个 URL 同源需要满足三个条件都相同：

- 协议相同（http / https）
- 域名相同
- 端口相同

只要有一个不同，就是跨域。

比如前端跑在 `https://www.example.com`，后端 API 在 `https://api.example.com`，虽然主域名一样，但子域名不同，也是跨域。

## Nginx 里加 CORS Header

解决思路很简单：在 Nginx 返回的响应里加上允许跨域的 HTTP Header。修改 Nginx 配置文件，在对应的 `location` 块里添加：

```nginx
location /api/ {
    proxy_pass http://127.0.0.1:8080;
    
    # 允许跨域的域名，* 表示允许所有
    add_header 'Access-Control-Allow-Origin' '*';
    
    # 允许的 HTTP 方法
    add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS';
    
    # 允许的请求头
    add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization';
    
    # 是否允许携带 Cookie
    add_header 'Access-Control-Allow-Credentials' 'true';
}
```

改完重新加载 Nginx：

```bash
nginx -s reload
```

搞定收工。配置服务器就是这样，有时候卡了一小时的问题，其实就是少写了两行配置项。

## 处理 OPTIONS 预检请求

上面的配置在简单请求里没问题，但如果请求带了自定义 Header 或者 Content-Type 是 `application/json`，浏览器会先发送一个 OPTIONS 预检请求。这个请求不会带 Cookie，也不会带请求体。

如果 Nginx 直接把 OPTIONS 请求转发给后端，而后端没有正确处理，就会报 405 或者 403。

更好的做法是在 Nginx 层直接响应 OPTIONS 请求：

```nginx
location /api/ {
    if ($request_method = 'OPTIONS') {
        add_header 'Access-Control-Allow-Origin' '*';
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS';
        add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization';
        add_header 'Access-Control-Max-Age' 86400;
        return 204;
    }
    
    proxy_pass http://127.0.0.1:8080;
    add_header 'Access-Control-Allow-Origin' '*';
    add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS';
    add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization';
}
```

这样 OPTIONS 预检请求就不会打到后端，响应速度也会更快。

## 生产环境不要写 *

上面的例子为了演示方便，我写的是 `Access-Control-Allow-Origin: *`，表示允许所有域名。这在开发环境没问题，但生产环境强烈建议改成具体的域名：

```nginx
add_header 'Access-Control-Allow-Origin' 'https://www.example.com';
```

如果允许多个域名，可以配合 map 使用：

```nginx
map $http_origin $cors_origin {
    default "";
    "~^https://www\.example\.com$" $http_origin;
    "~^https://admin\.example\.com$" $http_origin;
}

server {
    location /api/ {
        add_header 'Access-Control-Allow-Origin' $cors_origin;
        proxy_pass http://127.0.0.1:8080;
    }
}
```

这样只有白名单里的域名才能跨域访问，安全性更高。

## 我踩过的一个坑

有一次我加了 CORS Header 之后，前端还是报跨域错误。排查了很久才发现，Nginx 返回了 502，而 502 的响应里不会带上我配置的 `add_header`。浏览器看到的是没有 CORS Header 的 502 响应，于是报了跨域错误。

实际上真正的错误是后端服务没启动，跟 CORS 没关系。但浏览器的报错信息误导了我。

所以遇到 CORS 报错，建议先用 `curl -v` 直接请求后端，确认后端服务本身是通的，然后再排查 CORS 配置。

## 总结

Nginx 处理 CORS 的核心就是加几个响应头：

- `Access-Control-Allow-Origin`：允许的源
- `Access-Control-Allow-Methods`：允许的方法
- `Access-Control-Allow-Headers`：允许的请求头
- `Access-Control-Allow-Credentials`：是否允许携带凭证
- `Access-Control-Max-Age`：预检结果缓存时间

对于简单请求，直接加 Header 就行。对于复杂请求，最好单独处理 OPTIONS 预检。

不过最根本的解决办法还是前后端统一域名，比如都用 `www.example.com`，API 走 `/api/` 路径，这样就不存在跨域问题了。
