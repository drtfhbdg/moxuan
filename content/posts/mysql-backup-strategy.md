---
title: "数据库备份策略：从 mysqldump 到自动化脚本"
date: 2024-09-25T20:00:00+08:00
draft: false
tags: ["数据库", "MySQL", "MariaDB", "备份"]
categories: ["服务器运维"]
description: "分享我给小网站设计的数据库备份方案，包括全量备份、增量备份、压缩加密和异地存储的实现思路。"
---

数据库备份这件事，说起来容易，真要做好还挺考验耐心的。我之前就吃过亏：有一次手滑删错表，结果发现最近的备份是一周前的，中间的数据全丢了。从那以后，我对数据库备份就特别上心。

这篇文章分享一下我目前给小网站设计的数据库备份策略，从最简单的 mysqldump 开始，到自动化脚本和异地存储。

## 为什么 mysqldump 够用了

数据库备份工具有很多，比如 Percona XtraBackup、mydumper、二进制日志备份等。但对于小网站和个人项目来说，`mysqldump` 已经够用了。

它的优点：

- 简单易用，几乎所有 MySQL/MariaDB 都自带。
- 备份结果是 SQL 文本，方便查看和部分恢复。
- 恢复简单，一条命令就能导入。

缺点也很明显：

- 大数据库备份慢。
- 备份过程中会锁表（如果不加参数）。
- 全量备份占空间大。

对于几十 MB 到几个 GB 的数据库，mysqldump 完全没问题。

## 基础全量备份

最简单的备份命令：

```bash
mysqldump -u root -p 数据库名 > backup.sql
```

输入密码后就会生成一个 SQL 文件。

如果是备份所有数据库：

```bash
mysqldump -u root -p --all-databases > all_databases.sql
```

更 production 一点的写法，加上一些参数：

```bash
mysqldump -u root -p \
  --single-transaction \
  --routines \
  --triggers \
  --events \
  --all-databases > backup_$(date +%Y%m%d).sql
```

参数说明：

- `--single-transaction`：在导出前开启一个事务，保证数据一致性，对 InnoDB 表不锁表。
- `--routines`：备份存储过程和函数。
- `--triggers`：备份触发器。
- `--events`：备份定时事件。

## 压缩备份文件

SQL 文本压缩率通常很高，我习惯备份完直接压缩：

```bash
mysqldump -u root -p --all-databases | gzip > backup_$(date +%Y%m%d).sql.gz
```

一个 500MB 的 SQL 文件，压缩后可能只有 50MB。

恢复的时候这样解压导入：

```bash
gunzip < backup_20240925.sql.gz | mysql -u root -p
```

## 加密备份

如果数据库里有敏感信息，建议对备份文件加密。我用的是 GPG：

```bash
# 生成密钥（只需要做一次）
gpg --gen-key

# 加密备份文件
gpg --encrypt --recipient "你的名字" backup_20240925.sql.gz
```

加密后的文件后缀是 `.gpg`。解密：

```bash
gpg --decrypt backup_20240925.sql.gz.gpg > backup_20240925.sql.gz
```

## 自动化备份脚本

手动备份容易忘，我把它写成了脚本，每天凌晨自动跑。

```bash
#!/bin/bash

BACKUP_DIR="/data/backup/mysql"
DATE=$(date +%Y%m%d)
RETENTION_DAYS=30
DB_USER="backup"
DB_PASS="your_password"

mkdir -p "$BACKUP_DIR"

# 全量备份并压缩
mysqldump -u "$DB_USER" -p"$DB_PASS" \
  --single-transaction \
  --all-databases | gzip > "$BACKUP_DIR/all_$DATE.sql.gz"

# 删除过期备份
find "$BACKUP_DIR" -name "all_*.sql.gz" -type f -mtime +$RETENTION_DAYS -delete
```

然后用 crontab 定时执行：

```text
0 2 * * * /root/scripts/backup_mysql.sh > /dev/null 2>&1
```

## 增量备份思路

对于数据量比较大的情况，只做全量备份不够经济。可以结合二进制日志（binlog）做增量备份。

MySQL 的二进制日志记录了所有数据变更操作。开启 binlog 后，可以通过 `mysqlbinlog` 工具把增量变更导出：

```bash
mysqlbinlog /var/lib/mysql/binlog.000001 > increment.sql
```

恢复的时候，先恢复最近一次全量备份，再按顺序应用 binlog：

```bash
mysql -u root -p < full_backup.sql
mysql -u root -p < increment.sql
```

不过 binlog 管理比较复杂，要定期清理，还要考虑日志轮转。小网站如果没有特别大的数据量，每天全量备份其实更省心。

## 异地存储

备份文件如果只存在服务器本地，服务器挂了照样没。所以一定要有异地存储。

我的方案是：备份完成后用 `rsync` 同步到另一台便宜的备份服务器：

```bash
rsync -avz --delete "$BACKUP_DIR/" backup@backup-server:/backups/mysql/
```

也可以用对象存储，比如阿里云 OSS、腾讯云 COS。用对应厂商的 CLI 工具上传：

```bash
aliyun oss cp "$BACKUP_DIR/all_$DATE.sql.gz" oss://my-backup-bucket/mysql/
```

## 定期恢复演练

备份不是终点，能恢复才有意义。我每隔一两个月会做一次恢复演练：

1. 找一台测试机器。
2. 把备份文件传过去。
3. 导入数据库。
4. 检查数据是否完整，应用是否能正常连接。

恢复命令：

```bash
# 解压并导入
gunzip < all_20240925.sql.gz | mysql -u root -p

# 如果是单个数据库
gunzip < db_20240925.sql.gz | mysql -u root -p 数据库名
```

如果从来不演练，真到用的时候才发现备份文件损坏或者命令记错了，那就完蛋了。

## 总结

一个基本可用的数据库备份策略包括：

1. **每天全量备份**，用 mysqldump + gzip 压缩。
2. **保留 30 天历史备份**，过期自动删除。
3. **备份文件加密**，保护敏感数据。
4. **同步到异地存储**，防止单点故障。
5. **定期恢复演练**，确保备份可用。

这套方案对个人博客和小型网站来说已经足够。数据无价，希望大家都能重视备份，不要等到丢了才后悔。
