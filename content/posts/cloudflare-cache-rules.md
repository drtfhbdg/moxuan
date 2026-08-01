---
title: "研究了一下 Cloudflare 的缓存规则，静态资源直接起飞"
date: 2024-10-30T15:45:00+08:00
draft: false
tags: ["Cloudflare", "CDN", "前端优化", "缓存"]
categories: ["架构部署"]
description: "记录我给 Cloudflare 配置页面规则缓存静态资源的过程，以及缓存命中率提升后的效果。"
---

把域名托管给 Cloudflare 之后，发现首页加载还是差那么点意思。打开浏览器 F12 看了一下 Network，很多图片每次还要回源站去请求。

我的网站是 Hugo 生成的静态博客，图片、CSS、JS 这些文件基本不会变，非常适合长期缓存。Cloudflare 默认只会缓存某些静态扩展名，但图片目录的缓存策略还不够激进。

## Cloudflare 缓存层级

Cloudflare 有几种缓存相关功能：

1. **Caching -> Configuration**：全局缓存设置，比如缓存级别、浏览器缓存 TTL。
2. **Caching -> Rules / Page Rules**：自定义缓存规则，针对特定 URL 模式。
3. **Speed -> Optimization**：自动压缩、图片优化等。

我主要用的是 Page Rules，现在新版界面叫 Caching Rules。

## 配置页面规则

进入 Cloudflare 控制台，找到 Rules -> Page Rules，添加一条规则：

- **URL**：`*moxuan.de/images/*`
- **Settings**：
  - Cache Level: Cache Everything
  - Edge Cache TTL: 1 month
  - Browser Cache TTL: 1 month

`Cache Everything` 表示不管是什么类型的文件，都缓存到 Cloudflare 边缘节点。默认情况下 Cloudflare 不会缓存 HTML，只对静态文件缓存。但对纯静态博客来说，HTML 也可以缓存。

Edge Cache TTL 控制 CDN 边缘节点的缓存时间，Browser Cache TTL 控制浏览器本地缓存时间。

## 验证缓存是否命中

配置完后等几分钟生效。然后打开浏览器访问一张图片，看响应头：

```text
CF-Cache-Status: HIT
```

这个 Header 表示资源是从 Cloudflare 缓存直接返回的，没有回源。如果是 `MISS`，表示这次没命中，下次访问可能就会命中。

我配置之前图片的 `CF-Cache-Status` 大部分是 `MISS` 或者 `DYNAMIC`，加载时间几百毫秒。配置之后变成 `HIT`，加载时间降到了十几毫秒。

## 缓存 HTML 的注意事项

对于纯静态博客，可以把整个站点都设置 Cache Everything：

- **URL**：`*moxuan.de/*`
- **Settings**：
  - Cache Level: Cache Everything
  - Edge Cache TTL: 2 hours
  - Browser Cache TTL: 30 minutes

但这样有个问题：你更新了博客内容，访问者可能还是看到旧的缓存页面。解决方法有两个：

1. **发布新文章后手动清除缓存**：Cloudflare 控制台有 Purge Cache 功能。
2. **缩短 HTML 缓存时间**：比如只缓存 30 分钟，牺牲一点性能换取实时性。

我的博客更新不频繁，所以用了 2 小时缓存。每次发新文章后手动 Purge 一下。

## 使用 Cache Rules 替代 Page Rules

Cloudflare 现在更推荐用新的 Cache Rules，功能更强大，表达式也更灵活。

比如只缓存图片和静态文件：

```text
(http.request.uri.path contains "/images/") or (http.request.uri.path contains "/static/")
```

Action 选择：

- Cache eligibility: Eligible for cache
- Edge TTL: 1 month
- Browser TTL: 1 month

Cache Rules 比 Page Rules 的优先级更直观，新站建议直接用 Cache Rules。

## 配合 Origin Cache Control

如果源站 Nginx 已经设置了 `Cache-Control` 响应头，Cloudflare 默认会尊重源站的设置。比如 Nginx 里：

```nginx
location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2)$ {
    expires 6M;
    add_header Cache-Control "public, immutable";
}
```

这样 Cloudflare 会自动按 6 个月缓存这些文件，不需要额外配置 Page Rules。

但如果你用的是第三方托管或者不方便改源站配置，Page Rules 就很有用了。

## 监控缓存命中率

Cloudflare 控制台 Caching -> Analytics 里可以看到缓存命中率。我优化前大概是 40% 多，优化后稳定在 85% 以上。

缓存命中率越高，回源请求越少，源站压力越小，访问者加载也越快。

## 总结

这次 Cloudflare 缓存优化主要做了几件事：

1. 给图片目录配置 Cache Everything。
2. 设置较长的 Edge Cache TTL 和 Browser Cache TTL。
3. 对纯静态页面也适度缓存。
4. 发布新内容后手动 Purge 缓存。

边缘节点的物理距离优势确实明显。配置好之后，国内访问者打开我的博客，静态资源基本都是从最近的 Cloudflare 节点加载，速度提升很明显。

如果你的网站也是静态内容为主，强烈推荐花时间研究一下 Cloudflare 的缓存规则，这是性价比最高的性能优化之一。
