---
title: "手里的小鸡越来越多？部署 Uptime Kuma 给全员上探针"
date: 2024-04-05T16:30:00+08:00
draft: false
tags: ["监控", "Docker", "运维监控", "Telegram"]
categories: ["服务器运维"]
---

**为什么需要监控？**
最近沉迷在 NodeSeek 上捡垃圾，手里不知不觉攒了七八台各地的便宜 VPS。有些线路极其不稳定，动不动就掉线。平时要靠自己手动去 PING 看看死没死，效率太低。
为了解放自己，决定部署目前开源界最火的监控面板：Uptime Kuma。

**极速容器化部署**
老规矩，绝对不污染宿主机，直接用 Docker 一把梭。在母鸡（主服务器）上运行：
```bash
docker run -d --restart=always -p 3001:3001 -v uptime-kuma:/app/data --name uptime-kuma louislam/uptime-kuma:1
```
配合 Nginx 反代绑定个域名，配好 SSL 证书，颜值极高的中文后台就出来了。

**配置深度监控项**
我不光添加了简单的 `Ping` 和 `HTTP(s)` 检测，还用到了一些高级功能：
1. **TCP 端口检测**：单独监听了某些服务器的 SSH (22) 和数据库 (3306) 端口，防止系统活着但服务死了。
2. **DNS 解析检测**：监控我博客域名的解析有没有被污染。
3. **证书过期提醒**：设置了 SSL 证书还有 7 天过期时提前发通知。

**打通 Telegram 报警链路**
在 TG 上找 BotFather 申请了一个机器人 Token。在 Uptime Kuma 后台填入 Token 和我的 Chat ID。
测试了一下拔网线，几秒钟后手机 TG 就收到了 `[DOWN] Server-US-West 离线` 的精准报警。这下连睡觉都能安心了。