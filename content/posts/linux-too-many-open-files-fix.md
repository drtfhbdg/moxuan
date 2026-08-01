---
title: "服务突然 502？排查 Linux 'Too many open files' 报错踩坑记录"
date: 2024-04-22T23:15:00+08:00
draft: false
tags: ["Linux", "Nginx", "系统调优", "排错"]
categories: ["服务器运维"]
description: "记录一次 Nginx 报 502 的排查过程，最终定位到 Linux 文件描述符限制，以及我是怎么调整系统和应用参数的。"
---

前两天半夜，我的手机突然开始疯狂震动，原来是监控机器人在报警，说主站打不开了。我迷迷糊糊爬起来打开浏览器，果然看到硕大的 502 Bad Gateway。

当时第一个反应是：完了，不会是服务器被攻击了吧？赶紧登录 VPS 查看情况。

## 第一步：先确认服务器状态

登录进去之后，我先用 `top` 看了下整体负载。结果发现 CPU 和内存都挺正常的，负载也不高，不像是被 DDoS 或者程序跑死的样子。

然后去看 Nginx 的错误日志，路径一般在 `/var/log/nginx/error.log`：

```bash
tail -n 100 /var/log/nginx/error.log
```

日志里密密麻麻全是这种报错：

```text
2024/04/22 22:48:12 [crit] 1234#1234: *56789 accept4() failed (24: Too many open files)
```

`Too many open files`，这个错误我太熟了。Linux 里"一切皆文件"，每个 TCP 连接、每个打开的文件、每个 socket，背后都要占用一个文件描述符（File Descriptor，简称 FD）。系统为了防止单个进程把资源吃光，默认给每个进程设了一个上限，通常是 1024。

我的 Nginx 加上后端服务，并发一上来，文件描述符瞬间就满了，新的连接自然进不来，外面看到的就是 502。

## 第二步：确认当前限制

先不要急着改配置，先看一下当前的限制到底是多少。

查看系统级限制：

```bash
cat /proc/sys/fs/file-max
```

这个数字通常很大，比如几十万，系统级一般不是瓶颈。

查看用户级和进程级限制：

```bash
ulimit -n
```

我返回的是 1024，果然是默认值。

再看一下具体是哪些进程占用了大量 FD。先找到 Nginx worker 的 PID：

```bash
ps aux | grep nginx
```

然后看某个 worker 打开了多少文件：

```bash
lsof -p PID号 | wc -l
```

数字接近 1024，实锤了。

## 第三步：临时提升限制

为了先让服务恢复，我先临时把限制改大：

```bash
ulimit -n 65535
```

然后重载 Nginx：

```bash
systemctl reload nginx
```

网站立刻恢复正常。但这只是临时的，重启服务器或者重新登录 shell 之后又会变回 1024。

## 第四步：永久修改系统限制

要让修改永久生效，需要改 `/etc/security/limits.conf`。在文件末尾加上：

```text
* soft nofile 65535
* hard nofile 65535
```

这两行的意思是：所有用户（`*`）的软限制和硬限制都设为 65535。

不过这里有个坑，如果你是用 systemd 启动的服务，limits.conf 可能不生效。systemd 有自己的资源限制机制。

针对 systemd 管理的服务，比如 Nginx，建议直接修改服务的 service 文件。创建覆盖目录和文件：

```bash
mkdir -p /etc/systemd/system/nginx.service.d/
nano /etc/systemd/system/nginx.service.d/override.conf
```

内容写上：

```ini
[Service]
LimitNOFILE=65535
```

然后重载 systemd 配置并重启 Nginx：

```bash
systemctl daemon-reload
systemctl restart nginx
```

这样 Nginx 进程就能拿到 65535 的文件描述符限制了。

## 第五步：调整 Nginx 自身配置

光是改系统限制还不够，Nginx 自己也有连接数相关的配置。找到 `nginx.conf`，修改这两个地方：

```nginx
worker_rlimit_nofile 65535;

events {
    worker_connections 20480;
    use epoll;
    multi_accept on;
}
```

- `worker_rlimit_nofile`：每个 worker 进程能打开的最大文件数。
- `worker_connections`：每个 worker 能同时处理的最大连接数。
- `use epoll`：Linux 下推荐的事件模型。
- `multi_accept on`：一次 accept 多个连接，提高高并发下的效率。

改完之后重载：

```bash
nginx -t
systemctl reload nginx
```

## 第六步：后端应用也要检查

如果你的后端是 Node.js、Python 或者其他自己写的服务，也要检查它们的文件描述符限制。很多时候 Nginx 没问题了，但后端程序也会报同样的错。

比如一个 Python 服务用 systemd 管理，同样创建一个 override：

```bash
mkdir -p /etc/systemd/system/myapp.service.d/
nano /etc/systemd/system/myapp.service.d/override.conf
```

```ini
[Service]
LimitNOFILE=65535
```

然后 `daemon-reload` 加 `restart`。

## 第七步：验证和压测

改完配置之后，不能就这么算了，要验证一下是否真的生效了。

先看 Nginx worker 当前的限制：

```bash
cat /proc/NGINX_PID/limits | grep "Max open files"
```

数字应该是 65535。

然后用 `ab` 或者 `wrk` 压测一下。我本地装了 `wrk`，简单跑一下：

```bash
wrk -t4 -c10000 -d30s https://blog.moxuan.xin/
```

压测过程中一直盯着 error.log，确认没有再出现 `Too many open files`。同时用 `lsof -p PID | wc -l` 看 FD 使用量，稳定在一万左右，离 65535 还很远。

## 这次踩坑的总结

1. **遇到 502 不要慌**，先看日志，日志比猜测重要一百倍。
2. **Linux 一切皆文件**，socket 也是文件，连接数本质上受 FD 限制。
3. **ulimit 是用户级限制**，对 systemd 服务不一定生效， service override 更靠谱。
4. **Nginx 要同时调系统限制和自身 worker_connections**，只调一边没用。
5. **改完要验证**，压测一下比自我感觉更可靠。

这次故障从发现到彻底解决大概花了一个多小时。虽然熬夜很狼狈，但学到了不少东西。服务器运维就是这样，踩过的坑才是真金白银的经验。
