---
title: "1核1G的小鸡怎么跑 MySQL？记一次 MariaDB 的极限内存压榨"
date: 2024-09-12T16:20:00+08:00
draft: false
tags: ["数据库", "MySQL", "MariaDB", "性能调优", "Linux"]
categories: ["服务器运维"]
description: "记录我在一台 1 核 1G 内存的小 VPS 上优化 MariaDB 内存占用的过程，包括缓冲池、连接数和 Swap 配置。"
---

手里有一台极其廉价的 1核 1G 内存的 VPS，跑了一个 WordPress。最近只要稍微有点访问量，系统就会因为内存耗尽触发 OOM，直接把数据库进程杀掉，导致网页报 "Error establishing a database connection"。

加钱换大内存是不可能加钱的，这辈子都不可能加钱的。既然没钱升级，就只能靠改配置文件来极限压榨了。

## 先搞清楚内存被谁吃了

优化之前，先用 `free -h` 和 `ps aux --sort=-%mem | head` 看看内存占用情况。

我当时的状况大概是：

- 系统本身占用 200MB 左右
- MariaDB 启动后直接吃掉 400-500MB
- Nginx + PHP-FPM 占用 200MB 左右
- 留给业务缓存和突发请求的空间几乎没有

所以优化的核心目标就是把 MariaDB 的内存占用压下来。

## 调整 MariaDB 内存参数

MySQL/MariaDB 默认是为企业级大内存设计的，默认参数对小内存机器非常不友好。我的配置文件在 `/etc/mysql/mariadb.conf.d/50-server.cnf`，不同发行版路径可能略有不同。

主要改了这几个参数：

```ini
[mysqld]
# 最大连接数减小，小破站用不到那么多
max_connections = 50

# 核心大户：InnoDB 缓冲池
# 默认一般是 128M，我直接降到 32M
innodb_buffer_pool_size = 32M

# 关闭 performance_schema，省一点内存
performance_schema = off

# MyISAM 索引缓存
key_buffer_size = 8M

# 查询缓存，MySQL 8.0 已经移除了，MariaDB 还可以开
# 但我这里干脆关掉，因为查询模式多变，缓存命中率不高
query_cache_size = 0
query_cache_type = 0

# 排序和读缓存适当缩小
sort_buffer_size = 256K
read_buffer_size = 128K
read_rnd_buffer_size = 256K

# 连接线程栈大小
thread_stack = 192K

# InnoDB 日志缓冲区
innodb_log_buffer_size = 1M

# InnoDB 每表一个文件，方便管理
innodb_file_per_table = 1
```

改完之后重启 MariaDB：

```bash
systemctl restart mariadb
```

再看内存占用，MariaDB 从 500MB 降到了 250MB 左右，效果明显。

## 各个参数的作用

**max_connections**

默认可能是 151，对小站点来说太多了。每个连接都会消耗内存，连接数越少，总体内存占用越低。50 个连接对我的小站足够用了。

**innodb_buffer_pool_size**

这是 InnoDB 最重要的内存参数，用来缓存表数据和索引。默认 128M 对 1G 内存的机器来说太大了。降到 32M 后，查询性能确实会下降一些，因为缓存命中率低了，但总比 OOM 被杀掉强。

**performance_schema**

这是一个性能监控特性，会收集很多运行时统计信息。对调试有帮助，但很耗内存。小机器建议关掉。

**query_cache**

查询缓存会把相同的查询结果缓存起来。理论上能加速，但如果表更新频繁，缓存失效会很频繁，反而可能成为瓶颈。而且 query cache 本身也要占内存，小机器关掉更省心。

## 加个双保险：Swap

小内存机器千万不能关 Swap。虽然 Swap 速度比内存慢很多，但在内存紧张的时候，它能让系统不至于直接 OOM 杀进程。

我创建了一个 2G 的 Swap 文件：

```bash
# 创建 2G 的空文件
fallocate -l 2G /swapfile

# 设置权限
chmod 600 /swapfile

# 格式化为 swap
mkswap /swapfile

# 启用
swapon /swapfile

# 写入 fstab 永久生效
echo '/swapfile none swap sw 0 0' >> /etc/fstab
```

然后用 `swapon --show` 确认已经启用。

关于 Swap 有个常见误区：很多人觉得用了 Swap 就说明内存不够，性能会很差。其实 Linux 内核会尽量把不常用的内存页换到 Swap，把物理内存留给活跃的进程。轻度使用 Swap 是正常的，只要不是频繁大量换入换出，性能影响没有想象中大。

## 监控内存使用

优化完之后，我用几个命令持续观察了一段时间：

```bash
# 看整体内存和 Swap 使用
free -h

# 看 MariaDB 实际占用
ps aux | grep mariadb

# 看 Swap 使用是否剧烈
vmstat 1 10
```

`vmstat` 里的 `si` 和 `so` 表示每秒 Swap 换入换出的量。如果长期大于 0，说明内存是真的不够用了，这时候就该考虑升级配置了。

## 其他能做的优化

除了数据库参数，还有一些配套的优化：

1. **减少 PHP-FPM 进程数**：WordPress 这种 PHP 应用，FPM 进程太多也会吃光内存。
2. **开启 OPcache**：用内存缓存 PHP 字节码，虽然多占一点内存，但能显著降低 CPU 负载和响应时间。
3. **用对象缓存**：WordPress 可以用 Redis 或 Memcached 做对象缓存，减少数据库查询次数。

不过这些就超出数据库优化的范围了，以后有机会再写。

## 总结

小内存 VPS 跑数据库，核心思路就是"能关的关，能小的调小"：

1. **降低 max_connections**，够用就行
2. **减小 innodb_buffer_pool_size**，这是内存大户
3. **关闭 performance_schema 和 query_cache**
4. **合理配置 Swap 作为保险**
5. **持续监控内存和 Swap 使用情况**

优化完之后，我的 MariaDB 平时内存占用被死死按在了 250MB 左右，加上系统和其他服务，总体占用在 700MB 以内，基本不再触发 OOM。

穷人版服务器的调优乐趣就在于此。虽然配置寒酸，但通过合理调整，依然能让它稳定运行。当然，如果业务量真的上来了，该升级还是要升级，调优永远替代不了硬件。
