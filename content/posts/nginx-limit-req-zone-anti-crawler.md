---
title: "谁在偷我的带宽？用 Nginx 漏桶算法限流防恶意爬虫"
date: 2024-12-31T21:10:00+08:00
draft: false
tags: ["Nginx", "反爬虫", "限流", "漏桶算法"]
categories: ["服务器运维"]
---

**年底的突发流量**
本来在查资料，结果发现自己博客图片刷不出来了。看了一下账单，好家伙，CDN 流量半小时跑了 5G。
日志拉下来一分析，某个爬虫团队正在丧心病狂地遍历下载我博客所有的附件目录，而且 User-Agent 伪装成了正常的 Chrome 浏览器，Fail2ban 根据 UA 封不掉。

**降维打击：Nginx 限流配置**
既然分不清你是人是狗，那就直接按 IP 限制并发频率。在 Nginx 全局配置里启用 `limit_req_zone`（漏桶算法引擎）：

在 `http` 块中配置内存池：
```nginx
# 拿 10M 内存专门记录 IP 访问频率，限制每个 IP 每秒只能发起 2 个请求
limit_req_zone $binary_remote_addr zone=anti_spider:10m rate=2r/s;
```

在附件目录的 `location` 块中应用规则：
```nginx
location /images/ {
    # 允许有个缓冲区 (burst=5)，超过的直接不延迟 (nodelay)，直接送 503 报错
    limit_req zone=anti_spider burst=5 nodelay;
}
```

**测试与收网**
重新加载配置后，我自己用脚本疯狂并发请求了一波自己的图片。结果前 5 张图秒开，第 6 张瞬间收到 `503 Service Temporarily Unavailable`。
再看监控，那个疯狂的爬虫依然在试图抓取，但全被 Nginx 拒之门外，网络带宽瞬间回落到 KB 级别。带着清爽的服务器负载，安稳跨年。