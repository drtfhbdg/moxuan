---
title: "服务突然 502？排查 Linux 'Too many open files' 报错踩坑日记"
date: 2024-02-28T09:45:00+08:00
draft: false
tags: ["Linux", "排错", "Nginx", "系统调优"]
categories: ["服务器运维"]
---

**故障现场**
昨天半夜，挂在 VPS 上的一个高频采集脚本突然停止工作，Nginx 前端直接报 502 Bad Gateway。
登进服务器看了一眼 CPU 和内存，都非常空闲。去查服务的错误日志，发现满屏都是夺命报错：
`Accept error: accept: Too many open files`

**底层逻辑分析**
在 Linux 系统里，“一切皆文件”。不管是真实的文本文件，还是网络 Socket 连接，底层都要占用一个文件描述符（File Descriptor）。系统为了防止某个进程把资源耗尽，默认限制了一个进程最多只能打开 1024 个文件。
我的脚本因为并发太高，建立的网络连接瞬间超过了 1024，直接被系统内核掐断了。

**排查与验证过程**
先用命令看看当前进程到底占了多少描述符：
```bash
# 找出进程 PID
ps aux | grep my_script
# 查看该 PID 打开的文件数
lsof -p 12345 | wc -l
```
果不其然，数字飙到了 1040，彻底满了。

**终极解决思路（系统内核调优）**
既然限制了，那就改大一点。
1. 临时生效（重启失效）：`ulimit -n 65535`
2. 永久生效：修改 `/etc/security/limits.conf`，在末尾加上：
```text
* soft nofile 65535
* hard nofile 65535
```
3. 为了让 Nginx 也支持高并发，去改了 `nginx.conf`：
```nginx
worker_rlimit_nofile 65535;
events {
    worker_connections 20480;
}
```
全部改完后 `systemctl reload nginx`。压测了一波，一万并发稳如老狗，再也没有报过错。