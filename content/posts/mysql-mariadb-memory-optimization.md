---
title: "1核1G的小鸡怎么跑 MySQL？记一次 MariaDB 的极限内存压榨"
date: 2024-11-02T16:20:00+08:00
draft: false
tags: ["数据库", "MySQL", "性能调优", "Linux"]
categories: ["服务器运维"]
---

**资源报警**
手里有一台极其廉价的 1核 1G 内存的 VPS，跑了一个 WordPress。最近只要稍微有点访问量，系统就会因为内存耗尽触发 OOM，直接把数据库进程杀掉，导致网页报 "Error establishing a database connection"。

**对症下药：调整缓冲池**
MySQL/MariaDB 默认是为企业级大内存设计的，默认占用的 Buffer 太大了。既然没钱加内存，就只能靠改配置文件（`/etc/mysql/my.cnf`）来极限压榨了。

**修改参数（降级处理）**
禁用了内存杀手 InnoDB 的默认大缓存，调小各种连接参数：
```ini
[mysqld]
# 最大连接数减小，小破站用不到那么多
max_connections = 50
# 核心大户：InnoDB 缓冲池，从默认的 128M 降到 32M
innodb_buffer_pool_size = 32M
# 关闭性能相关的监控日志，省一点是一点
performance_schema = off
# 减小查询缓存和排序缓存
key_buffer_size = 8M
query_cache_size = 0
sort_buffer_size = 256K
```

**加个双保险：Swap 虚拟内存**
小内存机器千万不能关 Swap。我用文件硬生生分出了一块 2GB 的虚拟内存区域：
```bash
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
# 写入 fstab 永久生效
echo '/swapfile none swap sw 0 0' >> /etc/fstab
```
优化完毕重启数据库。现在平时内存占用被死死按在了 300MB 左右，穷人版服务器的调优乐趣就在于此。