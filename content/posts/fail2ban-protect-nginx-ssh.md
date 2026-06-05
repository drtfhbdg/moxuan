---
title: "服务器遭遇疯狂 CC 攻击，祭出 Fail2ban 封禁恶意 IP"
date: 2024-06-11T11:15:00+08:00
draft: false
tags: ["安全", "Fail2ban", "防火墙", "日志分析"]
categories: ["服务器运维"]
---

**被制裁的早晨**
早上起来发现博客打不开了，登进终端一看，Load Average（系统负载）飙到了 15。`top` 命令一看，Nginx 进程占了 99% 的 CPU。
用 `tail -n 100 /var/log/nginx/access.log` 一看，某个段的海外 IP 正在以每秒几百次的频率狂刷我的查询接口，典型的 CC 攻击。

**反击方案：Fail2ban 自动拉黑**
以前都是自己写 Shell 脚本定时读取日志然后加 `iptables` 规则，容易误杀还麻烦。直接装上 `Fail2ban`，让它自动监听日志并封锁 IP。

```bash
apt install fail2ban -y
```

**编写自定义的正则表达式监狱 (Jail)**
进入 `/etc/fail2ban/jail.local`，我自己写了一段专门针对 Nginx 恶意请求的防护规则：
```ini
[nginx-cc]
enabled = true
port = http,https
filter = nginx-cc
# 监控 Nginx 访问日志
logpath = /var/log/nginx/access.log
# 10秒内访问超过50次直接封禁 24 小时
findtime = 10
maxretry = 50
bantime = 86400
action = iptables-multiport[name=NoCC, port="http,https"]
```

同时，在 `/etc/fail2ban/filter.d/nginx-cc.conf` 里加上正则：
```ini
[Definition]
failregex = ^<HOST> -.*"GET /api/search.*HTTP.*"
ignoreregex =
```

**效果立竿见影**
重启 `fail2ban` 服务。用 `fail2ban-client status nginx-cc` 查看状态。一分钟后，直接封禁了 30 多个肉鸡 IP。整个服务器瞬间凉快下来，跟这些黑灰产斗智斗勇，也是运维的一大乐趣。