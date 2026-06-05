---
title: "研究了一下 Cloudflare 的页面规则，静态资源直接起飞"
date: 2024-09-28T15:45:00+08:00
draft: false
tags: ["Cloudflare", "CDN", "前端优化"]
categories: ["架构部署"]
---

把域名托管给 Cloudflare 之后，发现首页加载还是差那么点意思。打开浏览器 F12 看了一下 Network，很多图片每次还要回源站去请求。

直接进 CF 控制台，在 `Rules -> Page Rules` 里面加了一条规则。把图片路径（比如 `*moxuan.de/images/*`）的缓存级别直接调成了 `Cache Everything`（缓存所有内容），然后加上 Edge Cache TTL 设置为一个月。

等了几分钟生效后，再刷新网页，那些大图片的响应头直接变成了 `HIT`，加载速度从几百毫秒缩短到了十几毫秒。边缘节点的物理距离优势果然猛。