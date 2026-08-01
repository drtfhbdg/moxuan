---
title: "数据无价！写个 Shell 脚本把博客定时打包备份"
date: 2024-06-28T23:20:00+08:00
draft: false
tags: ["Shell", "自动化", "备份", "Crontab"]
categories: ["脚本开发"]
description: "记录我写的一个自动备份脚本，包含本地打包、异地同步、过期清理和告警通知，适合备份博客和中小型项目。"
---

经历了之前几次瞎搞把环境弄崩的惨痛教训后，我深刻体会到了"数据备份"的重要性。不能总指望云服务商不跑路，自己手里有备份才踏实。

最开始我是手动打包，每次改版之前 `tar` 一下，特别原始。后来项目多了，手动备份又麻烦又容易忘。干脆写了个 Shell 脚本，每天凌晨自动跑，本地存一份，远端再同步一份，保留最近 30 天的历史版本。

这篇文章就分享一下我的备份脚本是怎么写的，以及一些我认为重要的细节。

## 备份需求分析

在写脚本之前，我先想清楚了自己需要什么：

1. **备份对象**：博客源码、数据库、Nginx 配置、SSL 证书。
2. **备份频率**：每天一次，凌晨 2 点执行。
3. **保留策略**：本地保留 7 天，远端保留 30 天。
4. **异地存储**：不能只存在服务器本地，万一服务器挂了照样没。
5. **失败告警**：备份失败要通知我，不然出问题了我都不知道没备份。

## 脚本整体结构

我把脚本分成几个部分：

- 定义变量和路径
- 创建临时目录
- 分别备份源码、数据库、配置
- 打包并压缩
- 上传到远端
- 清理过期备份
- 发送通知

下面是完整脚本：

```bash
#!/bin/bash

# ========================================
# 自动备份脚本
# ========================================

# 基础配置
BACKUP_DIR="/data/backup"
TEMP_DIR="/tmp/backup_$(date +%Y%m%d_%H%M%S)"
DATE=$(date +%Y%m%d)
DATETIME=$(date +"%Y-%m-%d %H:%M:%S")
LOG_FILE="$BACKUP_DIR/backup.log"

# 要备份的内容
BLOG_DIR="/var/www/myblog"
NGINX_DIR="/etc/nginx"
SSL_DIR="/etc/letsencrypt"
DB_NAME="myblog"
DB_USER="dbuser"
DB_PASS="your_password"

# 远端存储配置
REMOTE_USER="backup"
REMOTE_HOST="backup.example.com"
REMOTE_DIR="/backups/myblog"

# 通知配置（可选）
WEBHOOK_URL="https://your-webhook-url"

# 创建目录
mkdir -p "$BACKUP_DIR"
mkdir -p "$TEMP_DIR"

# 记录开始
echo "[$DATETIME] 开始备份..." >> "$LOG_FILE"

# 1. 备份博客源码
if [ -d "$BLOG_DIR" ]; then
    cp -r "$BLOG_DIR" "$TEMP_DIR/blog"
    echo "[$DATETIME] 博客源码备份完成" >> "$LOG_FILE"
else
    echo "[$DATETIME] 错误：博客目录不存在" >> "$LOG_FILE"
    exit 1
fi

# 2. 备份数据库
mysqldump -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$TEMP_DIR/database.sql"
if [ $? -eq 0 ]; then
    echo "[$DATETIME] 数据库备份完成" >> "$LOG_FILE"
else
    echo "[$DATETIME] 错误：数据库备份失败" >> "$LOG_FILE"
    exit 1
fi

# 3. 备份配置文件
cp -r "$NGINX_DIR" "$TEMP_DIR/nginx"
cp -r "$SSL_DIR" "$TEMP_DIR/ssl"

# 4. 打包压缩
BACKUP_FILE="blog_backup_$DATE.tar.gz"
tar -czf "$BACKUP_DIR/$BACKUP_FILE" -C "$TEMP_DIR" .

if [ $? -eq 0 ]; then
    echo "[$DATETIME] 打包完成：$BACKUP_FILE" >> "$LOG_FILE"
else
    echo "[$DATETIME] 错误：打包失败" >> "$LOG_FILE"
    exit 1
fi

# 5. 同步到远端
rsync -avz --delete "$BACKUP_DIR/" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/"

if [ $? -eq 0 ]; then
    echo "[$DATETIME] 远端同步完成" >> "$LOG_FILE"
else
    echo "[$DATETIME] 错误：远端同步失败" >> "$LOG_FILE"
    # 同步失败不一定要退出，但至少要知道
fi

# 6. 清理本地过期备份（保留 7 天）
find "$BACKUP_DIR" -name "blog_backup_*.tar.gz" -type f -mtime +7 -delete

# 7. 清理远端过期备份（保留 30 天）
ssh "$REMOTE_USER@$REMOTE_HOST" "find $REMOTE_DIR -name 'blog_backup_*.tar.gz' -type f -mtime +30 -delete"

# 8. 清理临时目录
rm -rf "$TEMP_DIR"

# 9. 发送成功通知
curl -s -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "{\"msg\":\"博客备份完成：$BACKUP_FILE\"}"

echo "[$DATETIME] 备份流程结束" >> "$LOG_FILE"
```

## 几个重要的设计细节

### 临时目录用时间戳命名

每次备份用一个带时间戳的临时目录，避免并行执行或者上次没清理完导致文件混乱。结尾 `rm -rf "$TEMP_DIR"` 确保每次都清干净。

### 错误处理要到位

虽然 Shell 脚本的 `set -e` 可以让出错时自动退出，但我更喜欢在每个关键步骤后面手动判断 `$?`。这样我可以把具体错误写到日志里，而不是莫名其妙地中断。

### 数据库密码不要直接写脚本里

我上面为了演示把 `DB_PASS="your_password"` 直接写进去了，实际生产环境不建议这么做。更好的做法是：

1. 用 `.my.cnf` 配置文件存数据库凭证：

```ini
[mysqldump]
user=dbuser
password=your_password
```

2. 或者通过环境变量传入。

3. 也可以给数据库用户单独授权，只给 `SELECT` 和 `LOCK TABLES` 权限，最小权限原则。

### rsync 的 `--delete` 要慎用

我用 `rsync --delete` 保证远端和本地一致，但这也意味着如果本地误删了备份文件，远端也会被删。所以保留策略我分了两套：本地 7 天，远端 30 天。而且远端清理是通过 ssh 单独执行的 `find` 命令，不会受 `--delete` 影响。

### 远端服务器要独立

我专门用了一台便宜的存储型 VPS 当备份机，和主站不在同一个服务商。这样就算主站服务商出问题，备份也还在。这种异地备份的思想很重要，不要所有鸡蛋放一个篮子。

## 设置定时任务

脚本写好后，用 `crontab` 每天凌晨 2 点执行：

```bash
crontab -e
```

添加：

```text
0 2 * * * /root/scripts/backup.sh > /dev/null 2>&1
```

或者把输出重定向到日志文件：

```text
0 2 * * * /root/scripts/backup.sh >> /var/log/backup.log 2>&1
```

注意脚本本身已经写了日志，这里可以简单一点。

## 定期恢复演练

备份不是终点，能恢复才有意义。我每隔一两个月会从备份包里解压一次，检查一下文件是否完整，数据库能不能正常导入。

测试数据库恢复的命令：

```bash
mysql -u dbuser -p test_db < database.sql
```

如果从来不测试恢复，真到用的时候才发现备份文件损坏，那就完了。

## 总结

这个备份脚本虽然看起来不复杂，但已经能满足我个人博客和小型项目的备份需求。核心思路就是：

1. **本地打包 + 异地同步**
2. **分级保留策略**
3. **关键步骤报错处理**
4. **定期验证恢复能力**

数据无价，备份不是可选项，而是必修课。希望大家都能养成备份的好习惯，不要等到数据丢了才后悔。
