---
title: "连公网 IP 都不需要，用 Cloudflare Tunnels 安全发布内网服务"
date: 2024-12-05T17:15:00+08:00
draft: false
tags: ["Cloudflare", "内网穿透", "网络安全", "CDN"]
categories: ["架构部署"]
---

**没有公网 IP 的悲哀**
最近在自己电脑上开发了一个小面板，想发给朋友测试。但现在的家用宽带全是层层 NAT，根本拿不到公网 IP，就算拿到也封了 80 和 443 端口。

**优雅的降维方案：Cloudflare Tunnels**
以前玩 FRP 还要自己准备一台带带宽的云服务器，现在 Cloudflare 直接把这项企业级技术免费开放了。它的原理是让你的本地机器主动向 CF 边缘节点发起一条加密隧道，不需要暴露任何本地端口。

**三步极速打洞记录**
1. 在服务器/本地机器装上 CF 的守护进程 `cloudflared`：
```bash
wget [https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb](https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb)
dpkg -i cloudflared-linux-amd64.deb
```
2. 终端里执行登录验证 `cloudflared tunnel login`，浏览器会弹出一个页面绑定我的域名。
3. 创建隧道并绑定内部端口：
   直接用零信任仪表盘（Zero Trust Dashboard）可视化配置，把本地的 `http://localhost:8080` 映射到了我公网域名 `test.moxuan.de` 上。

不仅完美穿透了内网，流量还自动带上了 CF 的全球 CDN 加速和 WAF 防火墙保护。简直是做私有云盘和挂内网服务的终极神器。