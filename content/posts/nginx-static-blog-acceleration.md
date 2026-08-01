---
title: "用 Nginx 给静态博客加速的完整配置"
date: 2024-09-05T17:00:00+08:00
draft: false
tags: ["Nginx", "静态博客", "性能优化", "CDN"]
categories: ["服务器运维"]
description: "分享我用 Nginx 托管 Hugo 静态博客的完整配置，包括 SSL、Gzip、缓存和反向代理优化。"
---

我的博客是用 Hugo 生成的静态站点，生成之后就是一堆 HTML、CSS、JS 和图片文件。这种静态站点最适合用 Nginx 直接托管，速度快、配置简单、资源占用低。

这篇文章分享一下我目前用的 Nginx 配置，算是给静态博客的一个参考模板。

## 基础配置

最简单的静态博客配置只需要指定根目录和 index 文件：

```nginx
server {
    listen 80;
    server_name blog.moxuan.xin;
    root /var/www/blog/public;
    index index.html;
    
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

`try_files $uri $uri/ /index.html` 这个配置很重要，因为 Hugo 很多页面是干净的 URL，比如 `/about/` 而不是 `/about.html`。如果直接访问目录找不到文件，就回退到 `index.html`。

## 强制 HTTPS

现在 HTTP 基本已经被淘汰了，我直接把所有 80 端口的请求 301 跳转到 HTTPS：

```nginx
server {
    listen 80;
    server_name blog.moxuan.xin;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name blog.moxuan.xin;
    root /var/www/blog/public;
    index index.html;
    
    ssl_certificate /etc/letsencrypt/live/blog.moxuan.xin/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/blog.moxuan.xin/privkey.pem;
    
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

`http2` 建议加上，能提升多资源并发加载的效率。

## 启用 Gzip 压缩

静态博客的 HTML、CSS、JS 都是文本，开启 Gzip 能大幅减少传输体积。在 `http` 块里加：

```nginx
gzip on;
gzip_vary on;
gzip_proxied any;
gzip_comp_level 6;
gzip_types text/plain text/css text/xml application/json application/javascript application/rss+xml application/atom+xml image/svg+xml;
```

`gzip_comp_level` 是压缩级别，1 最快但压缩率低，9 最慢但压缩率高。一般 6 是个不错的平衡点。

## 静态资源缓存

对于 CSS、JS、图片这些不常变化的文件，可以让浏览器和 CDN 缓存久一点：

```nginx
location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2)$ {
    expires 6M;
    access_log off;
    add_header Cache-Control "public, immutable";
}
```

`expires 6M` 表示缓存 6 个月。如果以后更新了这些文件，可以通过改文件名（比如加 hash）来强制刷新。

## 图片懒加载配合

Nginx 本身不负责图片懒加载，这是前端的事情。但 Nginx 可以优化图片的传输方式。比如开启 `sendfile` 和 `tcp_nopush`：

```nginx
sendfile on;
tcp_nopush on;
tcp_nodelay on;
```

这些参数可以提升静态文件的发送效率。

## 安全相关 Header

顺手加一些安全响应头：

```nginx
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
```

这些不会直接影响性能，但能提升安全性。

## 配合 CDN 使用

如果博客流量比较大，建议前面套一个 CDN。我目前用的是 Cloudflare，配置好之后：

1. DNS 解析到 Cloudflare。
2. Cloudflare 回源到我的源站 Nginx。
3. 静态资源被缓存到 Cloudflare 的边缘节点。

CDN 配置我单独写了一篇文章，这里就不展开了。

## 完整的配置示例

把上面的内容整合起来，我的完整配置大概是这样：

```nginx
http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml application/json application/javascript application/rss+xml application/atom+xml image/svg+xml;
    
    server {
        listen 80;
        server_name blog.moxuan.xin;
        return 301 https://$server_name$request_uri;
    }
    
    server {
        listen 443 ssl http2;
        server_name blog.moxuan.xin;
        root /var/www/blog/public;
        index index.html;
        
        ssl_certificate /etc/letsencrypt/live/blog.moxuan.xin/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/blog.moxuan.xin/privkey.pem;
        
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        
        location / {
            try_files $uri $uri/ /index.html;
        }
        
        location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2)$ {
            expires 6M;
            access_log off;
            add_header Cache-Control "public, immutable";
        }
    }
}
```

## 验证配置

每次改完 Nginx 配置，一定要先用 `nginx -t` 检查语法：

```bash
nginx -t
```

没有报错再重载：

```bash
nginx -s reload
```

## 总结

静态博客的 Nginx 配置不复杂，但有几个点做好了能明显提升体验：

1. **强制 HTTPS**，启用 HTTP/2。
2. **开启 Gzip 压缩**，减少传输体积。
3. **静态资源长期缓存**，配合 CDN 效果更佳。
4. **加安全响应头**，提升安全性。

如果你也用 Hugo、Hexo、Jekyll 这类静态生成器，这个配置基本可以直接拿去用，改改域名和路径就行。
