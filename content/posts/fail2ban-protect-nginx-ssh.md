---
title: "服务器遭遇 CC 攻击，用 Fail2ban 自动封禁恶意 IP"
date: 2024-10-10T11:15:00+08:00
draft: false
tags: ["安全", "Fail2ban", "防火墙", "Nginx"]
categories: ["服务器运维"]
description: "记录一次博客被 CC 攻击的经历，以及我用 Fail2ban 自动识别并封禁恶意 IP 的完整配置过程。"
---

早上起来发现博客打不开了，登进终端一看，Load Average 飙到了 15。`top` 命令一看，Nginx 进程占了 99% 的 CPU。

用 `tail -n 100 /var/log/nginx/access.log` 一看，某个段的海外 IP 正在以每秒几百次的频率狂刷我的查询接口，典型的 CC 攻击。虽然带宽没被打满，但后端查询接口扛不住这么高的并发，服务器直接卡死了。

以前这种时候我都是手动写脚本看日志然后加 iptables 规则，容易误杀还麻烦。这次直接上 Fail2ban，让它自动监听日志并封锁 IP。

## 什么是 Fail2ban

Fail2ban 是一个入侵防御工具，它会监控指定的日志文件，用正则表达式匹配恶意行为，然后自动把对应的 IP 加入防火墙黑名单。

常见的使用场景：

- SSH 暴力破解
- Nginx 恶意爬虫
- WordPress 登录爆破
- 邮件服务器 spam 攻击

## 安装 Fail2ban

Debian/Ubuntu 直接 apt 安装：

```bash
apt update
apt install fail2ban -y
```

安装完成后默认会启动一个 `fail2ban` 服务，但默认配置不会启用任何规则。

## 配置 SSH 防护

虽然这篇文章主要讲 Nginx，但 SSH 防护是必开的。创建 `/etc/fail2ban/jail.local`：

```ini
[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
```

如果你改了 SSH 端口，`port` 这里要对应修改。

## 配置 Nginx CC 攻击防护

针对 Nginx 的 CC 攻击，我需要自己写一个 jail 和 filter。

### 1. 创建 jail

在 `/etc/fail2ban/jail.local` 里加上：

```ini
[nginx-cc]
enabled = true
port = http,https
filter = nginx-cc
logpath = /var/log/nginx/access.log
findtime = 10
maxretry = 50
bantime = 86400
action = iptables-multiport[name=NoCC, port="http,https"]
```

参数说明：

- `findtime = 10`：10 秒时间窗口。
- `maxretry = 50`：10 秒内同一个 IP 访问超过 50 次就封禁。
- `bantime = 86400`：封禁 24 小时。

这些阈值要根据自己网站的正常流量调整。如果正常用户刷新比较多，可以把 `maxretry` 调大一点。

### 2. 创建 filter

在 `/etc/fail2ban/filter.d/nginx-cc.conf` 里写匹配规则：

```ini
[Definition]
failregex = ^<HOST> -.*"(GET|POST) /api/search.*HTTP.*"
ignoreregex =
```

这个规则匹配访问 `/api/search` 接口的请求。`<HOST>` 是 Fail2ban 内置的变量，表示 IP 地址。

如果你的攻击目标是其他路径，可以修改正则。比如匹配所有请求：

```ini
failregex = ^<HOST> -.*"(GET|POST) .*HTTP.*"
```

但这样可能误伤正常用户和高并发爬虫，建议针对具体被攻击的接口写规则。

### 3. 重启服务

```bash
systemctl restart fail2ban
```

查看状态：

```bash
fail2ban-client status nginx-cc
```

查看被封禁的 IP：

```bash
fail2ban-client status nginx-cc banned
```

## 效果验证

重启 Fail2ban 后，我观察了十几分钟。一开始日志里还是疯狂的请求，但大概一分钟后，请求量骤降。

用 `fail2ban-client status nginx-cc` 一看，已经封禁了 30 多个 IP。整个服务器负载很快从 15 降到了 1 以下。

## 更精细的规则

只匹配一个接口有时候不够。后来我加了几条规则：

**匹配 WordPress 登录爆破**

```ini
[wordpress-login]
enabled = true
port = http,https
filter = wordpress-login
logpath = /var/log/nginx/access.log
maxretry = 5
bantime = 86400
```

filter：

```ini
[Definition]
failregex = ^<HOST> -.*"POST /wp-login.php.*HTTP.*"
```

**匹配 404 扫描**

有些扫描器会批量请求不存在的路径，也可以用 Fail2ban 封禁：

```ini
[nginx-404]
enabled = true
port = http,https
filter = nginx-404
logpath = /var/log/nginx/access.log
maxretry = 20
findtime = 60
bantime = 3600
```

filter：

```ini
[Definition]
failregex = ^<HOST> -.*"(GET|POST) .*HTTP.*" 404
```

## 白名单设置

如果你有自己的固定 IP，建议加到白名单，防止被误封。在 `/etc/fail2ban/jail.local` 的 `[DEFAULT]` 段加：

```ini
[DEFAULT]
ignoreip = 127.0.0.1/8 你的公网IP
```

## 查看和手动解封

如果不小心封错了 IP，可以手动解封：

```bash
fail2ban-client set nginx-cc unbanip IP地址
```

## 总结

Fail2ban 是个非常实用的安全工具，特别适合我这种小站长。它的核心优势是：

1. **自动分析日志**，不用自己写复杂脚本。
2. **自动封禁 IP**，响应速度快。
3. **规则灵活**，可以针对各种攻击模式定制。

这次 CC 攻击让我深刻体会到，小网站也需要基本的安全防护。fail2ban 配置一次，长期受益，强烈建议大家至少把 SSH 和 Nginx 的防护规则开起来。
