---
title: "Linux 日志排查：journalctl 实战与常见问题"
date: 2024-05-08T19:40:00+08:00
draft: false
tags: ["Linux", "journalctl", "日志", "排错"]
categories: ["服务器运维"]
description: "分享我用 journalctl 排查 Linux 系统日志的经验，包括常用命令、过滤技巧和持久化配置。"
---

之前我查日志基本都是直接去 `/var/log/` 下面翻文件，比如 `syslog`、`nginx/error.log`、`auth.log` 这些。后来系统升级之后发现有些日志找不到了，一查才知道现在很多发行版都用 systemd 的 journal 来统一管理日志了。

`journalctl` 就是查看这些日志的命令。一开始我觉得挺麻烦的，因为参数太多了，记都记不住。但用熟了之后发现，它比传统日志文件方便很多，尤其是过滤和查询历史日志的时候。

这篇文章记录一下我常用的 journalctl 命令和一些踩坑经验。

## journalctl 是什么

systemd 接管了很多系统服务，它把这些服务产生的日志统一收集到一个二进制格式的日志数据库里，也就是 journal。`journalctl` 就是查询这个数据库的工具。

相比文本日志，journal 的优势是：

- 结构化存储，查询效率高。
- 可以按服务、时间、优先级等多种维度过滤。
- 支持持久化配置，重启后日志不会丢。

缺点是它不是纯文本，不能直接 `cat` 或者 `grep`，必须用 `journalctl` 来读。

## 最基础的用法

不加参数直接运行：

```bash
journalctl
```

会按时间顺序输出所有日志，最新的在最后。按 `Shift+G` 或者 `End` 键跳到最下面看最新日志。

这个命令默认用 `less` 风格的分页，如果你只想看最近的几十行，可以用 `-n`：

```bash
journalctl -n 50
```

类似 `tail -n 50`。

## 查看某个服务的日志

这个是我最常用的。比如看 Nginx 的日志：

```bash
journalctl -u nginx
```

看 SSH 服务：

```bash
journalctl -u sshd
```

如果服务名不确定，可以用 `systemctl list-units` 查看。

还可以加 `-f` 实时跟踪，类似 `tail -f`：

```bash
journalctl -u nginx -f
```

调试服务启动问题的时候特别有用。

## 按时间过滤

有时候日志太多，只想看某个时间段的。journalctl 支持 `--since` 和 `--until`。

看今天凌晨 2 点到 4 点的 Nginx 日志：

```bash
journalctl -u nginx --since "2024-05-08 02:00:00" --until "2024-05-08 04:00:00"
```

也支持相对时间：

```bash
journalctl --since "1 hour ago"
journalctl --since "30 minutes ago"
journalctl --since today
```

我排查故障的时候经常先用 `--since "1 hour ago"` 缩小范围。

## 按优先级过滤

journal 给日志分了 0 到 7 共 8 个优先级，从 `emerg` 到 `debug`。只看错误级别及以上的日志：

```bash
journalctl -p err
```

只看警告和错误：

```bash
journalctl -p warning..err
```

级别名称对应：

- `emerg` (0)：系统不可用
- `alert` (1)：必须立即处理
- `crit` (2)：严重错误
- `err` (3)：错误
- `warning` (4)：警告
- `notice` (5)：正常但重要
- `info` (6)：普通信息
- `debug` (7)：调试信息

## 查看内核日志

内核相关的日志用 `-k`：

```bash
journalctl -k
```

相当于原来的 `dmesg`。排查硬件驱动、内核模块问题的时候很有用。

## 查看指定进程的日志

如果你知道进程的 PID，可以这样查：

```bash
journalctl _PID=1234
```

这个在排查某个具体程序的时候很方便，不用去翻整个服务日志。

## 持久化配置

journal 默认可能是内存存储，重启后日志就丢了。如果你想保留历史日志，需要开启持久化。

创建目录并重启服务：

```bash
sudo mkdir -p /var/log/journal
sudo systemd-tmpfiles --create --prefix /var/log/journal
sudo systemctl restart systemd-journald
```

然后日志就会写到 `/var/log/journal/` 目录下，重启不会丢失。

你还可以限制日志占用的最大空间。编辑 `/etc/systemd/journald.conf`：

```ini
[Journal]
Storage=persistent
SystemMaxUse=500M
MaxFileSec=7day
```

- `SystemMaxUse`：journal 最多占用多少磁盘空间。
- `MaxFileSec`：单个日志文件保留多久。

改完重启 journald：

```bash
systemctl restart systemd-journald
```

我那个小硬盘 VPS 就设了 500M，不然日志能吃掉好几 G。

## 清理旧日志

如果磁盘空间突然满了，可以手动清理 journal：

保留最近 100M：

```bash
journalctl --vacuum-size=100M
```

保留最近 7 天：

```bash
journalctl --vacuum-time=7d
```

这两个命令很常用，建议记一下。

## 输出格式调整

默认输出比较长，如果你只想快速浏览，可以用 `--no-pager` 不分页，或者 `--output=short` 简化格式。

我常用的组合：

```bash
journalctl -u nginx --since "1 hour ago" --no-pager -o short
```

如果要把日志导出到文件，可以重定向：

```bash
journalctl -u nginx --since today > /tmp/nginx-today.log
```

## 我踩过的一个坑

有一次我改完 `journald.conf` 之后没重启 `systemd-journald`，结果配置一直没生效，日志还是存在内存里。重启机器后发现日志全丢了，排查问题少了很多线索。

从那以后我养成了一个习惯：每次改完 journald 配置，一定要执行 `systemctl restart systemd-journald`，然后 `journalctl --disk-usage` 看一下实际占用了多少空间，确认配置生效了。

## 总结

journalctl 看起来参数多，但日常用得顺手的就那几个：

- `journalctl -u 服务名`：看某个服务的日志
- `journalctl -f`：实时跟踪
- `journalctl --since "时间"`：按时间过滤
- `journalctl -p err`：按错误级别过滤
- `journalctl -n 数字`：看最近 N 行
- `journalctl --vacuum-size=100M`：清理日志

如果你还在用传统方式查日志，建议花半小时熟悉一下 journalctl，真的能省不少时间。
