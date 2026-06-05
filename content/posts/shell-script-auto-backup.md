---
title: "数据无价！写个 Shell 脚本把博客定时打包备份"
date: 2024-08-02T23:20:00+08:00
draft: false
tags: ["Shell", "自动化", "备份", "Crontab"]
categories: ["脚本开发"]
---

经历了之前几次瞎搞把环境弄崩的惨痛教训后，深刻体会到了“数据备份”的重要性。不能总指望云服务商不跑路，自己手里有备份才踏实。

用 Shell 简单写了个打包脚本，每天凌晨两点自动把博客目录打包成 `tar.gz` 压缩文件。
```bash
#!/bin/bash
BACKUP_DIR="/root/backup"
TARGET_DIR="/var/www/myblog"
DATE=$(date +%Y%m%d)

# 打包压缩
tar -czvf $BACKUP_DIR/blog_$DATE.tar.gz $TARGET_DIR

# 删掉7天前的旧备份，省点硬盘
find $BACKUP_DIR -name "blog_*.tar.gz" -type f -mtime +7 -exec rm {} \;
```
结合 `crontab -e` 挂在后台：`0 2 * * * /root/scripts/backup.sh`。全自动运行，再也不怕自己手残删库了。