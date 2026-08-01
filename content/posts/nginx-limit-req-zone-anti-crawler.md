---
title: "谁在偷我的带宽？用 Nginx 漏桶算法限流防恶意爬虫"
date: 2024-08-25T21:10:00+08:00
draft: false
tags: ["Nginx", "反爬虫", "限流", "漏桶算法"]
categories: ["服务器运维"]
description: "记录一次博客被恶意爬虫大量抓取的应对过程，用 Nginx 的 limit_req_zone 实现按 IP 限流，保护带宽和服务器资源。"
---

本来在查资料，结果发现自己博客图片刷不出来了。看了一下账单，好家伙，CDN 流量半小时跑了 5G。

日志拉下来一分析，某个爬虫正在丧心病狂地遍历下载我博客所有的附件目录，而且 User-Agent 伪装成了正常的 Chrome 浏览器，靠封 UA 根本封不掉。

既然分不清你是人是爬虫，那就直接按 IP 限制并发频率。这篇文章记录我用 Nginx 漏桶算法限流的过程。

## 什么是漏桶算法

漏桶算法（Leaky Bucket）是一种流量整形算法。想象一个底部有洞的桶，水（请求）以任意速度倒入桶中，但流出的速度是固定的。如果倒入的速度太快，桶就会满，多出来的水就溢出了。

在 Nginx 里，这个"桶"就是内存中的一块区域，用来记录每个 IP 的请求频率。请求进来先放到桶里，如果频率超过设定值，就直接拒绝服务。

Nginx 通过 `limit_req_zone` 和 `limit_req` 两个指令实现漏桶限流。

## 配置 limit_req_zone

首先在 Nginx 配置文件的 `http` 块里定义限流区域：

```nginx
http {
    # 定义一个名为 anti_spider 的限流区域
    # $binary_remote_addr 表示用客户端 IP 作为 key
    # 10m 表示分配 10MB 内存存储状态
    # rate=2r/s 表示每个 IP 每秒最多 2 个请求
    limit_req_zone $binary_remote_addr zone=anti_spider:10m rate=2r/s;
    
    # 其他配置...
}
```

参数说明：

- `$binary_remote_addr`：客户端 IP 的二进制形式，比字符串形式更省内存。
- `zone=anti_spider:10m`：区域名称叫 anti_spider，分配 10MB 内存。
- `rate=2r/s`：每个 key（这里是每个 IP）每秒允许 2 个请求。

10MB 内存大概能存 16 万个 IP 的状态，对个人博客来说完全够用。

## 在 location 里应用限流

定义好区域后，在需要限流的 `location` 里使用 `limit_req`：

```nginx
server {
    listen 80;
    server_name blog.example.com;
    
    location /images/ {
        limit_req zone=anti_spider burst=5 nodelay;
        alias /var/www/blog/images/;
        expires 30d;
    }
}
```

- `zone=anti_spider`：使用刚才定义的限流区域。
- `burst=5`：允许突发 5 个请求。也就是说，前 5 个请求可以先进桶里排队。
- `nodelay`：不延迟处理，超过速率的请求直接返回 503，而不是排队等待。

对于图片、附件这些静态资源，用 `nodelay` 比较合理。爬虫每秒请求几百次，让它排队没意义，直接拒绝最干脆。

## 实际效果

重新加载配置后，我自己用脚本并发请求了一波图片做测试：

```bash
ab -n 100 -c 10 https://blog.example.com/images/test.jpg
```

结果前几个请求返回 200，后面的全部返回 503。这说明限流生效了。

再看监控，那个疯狂的爬虫依然在尝试抓取，但全被 Nginx 拒之门外，带宽占用瞬间回落到正常水平。

## 全局限流 vs 局部限流

上面是按 `location` 限流，只针对 `/images/` 目录。如果你发现全站都被爬，可以在 `server` 块里全局应用：

```nginx
server {
    limit_req zone=anti_spider burst=10 nodelay;
    
    location / {
        proxy_pass http://localhost:8080;
    }
}
```

但全局限流要慎重，因为正常用户如果点得快，也可能触发限制。建议先针对静态资源目录限流，观察效果再决定是否扩大范围。

## 配合日志分析

限流之后，建议把被拒绝的请求记录到单独日志里，方便分析：

```nginx
limit_req_zone $binary_remote_addr zone=anti_spider:10m rate=2r/s;

server {
    location /images/ {
        limit_req zone=anti_spider burst=5 nodelay;
        error_page 503 = @rate_limited;
    }
    
    location @rate_limited {
        access_log /var/log/nginx/rate_limit.log main;
        return 503;
    }
}
```

通过分析 `rate_limit.log`，可以看到哪些 IP 在大量请求，必要时再用防火墙封禁。

## 另一个维度：限制连接数

除了限制请求频率，Nginx 还可以限制并发连接数，用的是 `limit_conn_zone` 和 `limit_conn`：

```nginx
http {
    limit_conn_zone $binary_remote_addr zone=addr:10m;
    
    server {
        location / {
            limit_conn addr 10;
        }
    }
}
```

这表示每个 IP 同时最多只能建立 10 个连接。对于防止某些下载工具开大量线程很有用。

## 总结

这次被爬虫偷带宽的经历让我学到了几件事：

1. **不要只依赖 User-Agent 判断爬虫**，现在很多爬虫会伪装 UA。
2. **按 IP 限流是比较通用的防御手段**，对人影响小，对爬虫效果明显。
3. **`limit_req_zone` 配置简单，但效果很好**。
4. **限流后要监控日志**，看看是哪些 IP 在搞事情。

如果你也运营一个小网站，建议提前把 Nginx 限流配置好。等真正被爬的时候再临时应对，可能已经损失了不少流量费用。
