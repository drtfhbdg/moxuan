---
title: "抛弃向日葵和 ToDesk，用 Tailscale 组建个人的大局域网"
date: 2024-03-12T20:10:00+08:00
draft: false
tags: ["内网穿透", "Tailscale", "WireGuard", "远程桌面"]
categories: ["网络工程"]
---

**商业软件的痛点**
最近在外面想远程连回出租屋里的台式机搞点开发，用向日葵和 ToDesk 不是限速就是画质糊得像马赛克，而且免费版动不动就排队，实在忍不了了。
既然咱有云服务器，为啥不自己搞个内网穿透？

**技术选型：为什么是 Tailscale？**
对比了 FRP 和 ZeroTier，最后选了基于 WireGuard 协议的 Tailscale。它的打洞（NAT Traversal）能力极其变态，配置简直是傻瓜式，而且所有节点都会被分配一个固定的 `100.x.x.x` 的局域网 IP。

**部署踩坑记录**
在 Linux 服务器和家里 Windows 电脑上分别装好客户端：
```bash
curl -fsSL [https://tailscale.com/install.sh](https://tailscale.com/install.sh) | sh
tailscale up
```
本来以为直接连就行了，结果发现两边 PING 延迟高达 300ms，走的居然是官方国外的 DERP 中继服务器，没有直连（打洞失败）。

**自建 DERP 中继服务器（终极加速）**
为了解决延迟，我决定用手里国内的腾讯云服务器自建中继节点。
拉了一个官方的 Docker 镜像：
```yaml
version: '3'
services:
  derper:
    image: fredliang/derper:latest
    ports:
      - 3478:3478/udp
      - 443:443/tcp
    environment:
      - DERP_DOMAIN=derp.moxuan.de
```
配置好证书后，在 Tailscale 的 ACL 规则里强制指定我的节点。再次用 Windows 自带的 RDP 远程桌面连接家里电脑，延迟只有 20ms，画质无损拉满，拖动窗口丝般顺滑。真香！