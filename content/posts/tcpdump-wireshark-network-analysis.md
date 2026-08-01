---
title: "设备连不上外网？用 TCPdump 和 Wireshark 抓包排查"
date: 2024-10-20T09:20:00+08:00
draft: false
tags: ["网络抓包", "Wireshark", "tcpdump", "排障"]
categories: ["网络工程"]
description: "记录一次 Linux 工控机无法访问外网的排查过程，用 tcpdump 抓包后在 Wireshark 中分析，最终定位到 MTU 设置问题。"
---

机房里有一台装了 Linux 的旧工控机，局域网内可以互相 Ping 通，但就是死活无法访问外网的 API 接口。路由器的防火墙查了没拦截，工控机网关也没配错。

面对这种灵异事件，单纯看配置已经没用了，只能深入协议栈去抓包看底层数据。

## TCPdump 基础用法

Linux 自带的 `tcpdump` 是抓包神器。它的基本语法是：

```bash
tcpdump [选项] [过滤表达式]
```

常用选项：

- `-i eth0`：指定网卡
- `-c 100`：抓取 100 个包后停止
- `-w file.pcap`：把抓包结果保存到文件
- `-n`：不解析主机名，显示 IP
- `-v` / `-vv` / `-vvv`：显示更详细的信息

## 我的抓包操作

连上工控机的 SSH，针对外网接口的 80 和 443 端口抓包：

```bash
# 抓取网卡 eth0 上，目标端口为 80 或 443 的 1000 个包
tcpdump -i eth0 port 80 or port 443 -c 1000 -w /tmp/offline_capture.pcap
```

`-w` 参数会把数据包保存为 `.pcap` 格式，方便后续用 Wireshark 分析。

如果你只是想在终端快速看一下，可以不加 `-w`：

```bash
tcpdump -i eth0 port 443 -n
```

## 常用过滤表达式

抓包的时候通常会加过滤条件，避免抓到太多无关数据。

按 IP 过滤：

```bash
tcpdump host 192.168.1.1
```

按端口过滤：

```bash
tcpdump port 443
```

按协议过滤：

```bash
tcpdump icmp
tcpdump tcp
tcpdump udp
```

组合条件：

```bash
tcpdump -i eth0 'tcp port 443 and host 8.8.8.8'
```

## 用 Wireshark 离线分析

把 `.pcap` 文件下载到自己的电脑上，用 Wireshark 打开。

Wireshark 的界面虽然很复杂，但常用的功能就几个：

1. **过滤栏**：输入 `ip.addr == 192.168.1.1` 只显示某个 IP 的包。
2. **Follow TCP Stream**：右键一个 TCP 包，选择 "Follow -> TCP Stream"，可以看到完整的会话内容。
3. **Statistics -> Conversations**：看哪些 IP 之间通信最多。
4. **Expert Info**：自动标记一些异常，比如重传、乱序等。

## 定位问题

我打开抓到的包，用 "Follow TCP Stream" 跟踪一个外网 API 请求的数据流。

正常情况下，TCP 三次握手应该是：

1. 客户端发 SYN
2. 服务端回 SYN, ACK
3. 客户端回 ACK

但我看到的是：

1. 工控机发 SYN
2. 外部服务器回 SYN, ACK
3. **工控机没有回 ACK，而是直接发了 RST（重置连接）**

这说明连接在工控机这边被主动中断了。

进一步看包头的参数，发现这台工控机的 MTU 被改成了 900。正常的以太网 MTU 是 1500，900 这个值非常奇怪。

MTU 太小会导致大包被分片。如果某些网络设备或者目标服务器不支持分片，或者分片后的包无法正确重组，连接就会失败。

## 修复

找到问题后，修复就很简单了。把 MTU 改回 1500：

```bash
ip link set eth0 mtu 1500
```

验证：

```bash
ip addr show eth0
```

如果要永久生效，可以写入网络配置文件。Debian/Ubuntu 在 `/etc/network/interfaces` 或者 netplan 配置里加 `mtu 1500`。

改完之后，外网 API 立刻通了。

## 另一个实用场景：排查 DNS 问题

TCPdump 不仅可以抓 TCP，抓 UDP DNS 包也很有用：

```bash
tcpdump -i eth0 port 53 -n
```

如果你发现 DNS 请求发出去但没收到响应，或者收到响应但解析结果不对，这个命令能帮你快速定位。

## 排查 HTTP 接口问题

对于 HTTP/HTTPS 接口，如果你需要看应用层内容，可以用 `tcpdump -A` 以 ASCII 形式打印数据：

```bash
tcpdump -i eth0 port 80 -A -s 0
```

`-s 0` 表示不截断数据包，抓完整内容。

不过 HTTPS 是加密的，抓到的内容看不到明文。这种情况下可以改用 Web 服务器日志或者浏览器开发者工具。

## 抓包注意事项

1. **抓包会产生大量数据**，注意磁盘空间。尤其是高流量服务器，别一不小心把磁盘撑满。
2. **生产环境抓包要谨慎**，可能会影响性能。
3. **注意隐私合规**，抓包可能抓到敏感信息，分析完及时删除。

## 总结

这次故障让我深刻体会到：在网络世界里，数据包永远不会说谎。当配置看起来都对但就是不工作的时候，抓包往往能直接定位问题。

我的排查流程一般是：

1. 先看基础网络配置（IP、网关、DNS、防火墙）。
2. 用 `ping` 和 `traceroute` 确认连通性。
3. 用 `tcpdump` 抓包，保存为 pcap。
4. 用 Wireshark 离线分析协议细节。
5. 根据数据包行为定位根因。

掌握 tcpdump + Wireshark 这对组合，网络排障能力会有质的飞跃。
